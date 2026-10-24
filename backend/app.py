from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from pathlib import Path
import joblib
import pandas as pd
import numpy as np
import os
import asyncio
import json
import time
import serial
import threading
from google import genai
from google.genai import types

# ----------------------------------------------------
# 1. SETUP
# ----------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / "key.env")

MODEL_FILE = "crop_recommender_model_FINAL_FIX_NEW.pkl"
DATA_FILE = "Crop_recommendation.csv"

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None

app = Flask(__name__)
CORS(app)

# ----------------------------------------------------
# 1.5 ARDUINO SERIAL SETUP
# ----------------------------------------------------
ARDUINO_PORT = 'COM09'
BAUD_RATE = 9600

# Starts purely at 0 so no artificial values are generated on initial load
LATEST_SENSOR_DATA = {"N": 0.0, "P": 0.0, "K": 0.0, "ph": 0.0, "methane_ppm": 0.0}

def read_from_arduino():
    """Runs continuously in the background to fetch USB data."""
    global LATEST_SENSOR_DATA
    try:
        ser = serial.Serial(ARDUINO_PORT, BAUD_RATE, timeout=1)
        print(f"🔌 Connected to Arduino on {ARDUINO_PORT}")
        time.sleep(2)

        while True:
            if ser.in_waiting > 0:
                raw_line = ser.readline().decode('utf-8', errors='ignore').strip()
                if raw_line:
                    try:
                        data = json.loads(raw_line)
                        LATEST_SENSOR_DATA["N"] = float(data.get("N", LATEST_SENSOR_DATA["N"]))
                        LATEST_SENSOR_DATA["P"] = float(data.get("P", LATEST_SENSOR_DATA["P"]))
                        LATEST_SENSOR_DATA["K"] = float(data.get("K", LATEST_SENSOR_DATA["K"]))
                        LATEST_SENSOR_DATA["ph"] = float(data.get("ph", LATEST_SENSOR_DATA["ph"]))
                        LATEST_SENSOR_DATA["methane_ppm"] = float(data.get("methane_ppm", LATEST_SENSOR_DATA["methane_ppm"]))
                    except json.JSONDecodeError:
                        pass
    except Exception as e:
        print(f"⚠️ Arduino Serial Error (Continuing without hardware): {e}")


# ----------------------------------------------------
# 2. LOAD MODEL & DATA
# ----------------------------------------------------
try:
    RF_model = joblib.load(MODEL_FILE)
    print("✅ Backend Model loaded.")
except:
    RF_model = None
    print("❌ Model not found.")

try:
    df = pd.read_csv(DATA_FILE)
    avg_requirements = df.groupby("label")[["N", "P", "K", "ph"]].mean().to_dict("index")
    avg_requirements = {k.lower(): v for k, v in avg_requirements.items()}

    # Also compute std deviations per crop for smarter scoring
    std_requirements = df.groupby("label")[["N", "P", "K", "ph"]].std().to_dict("index")
    std_requirements = {k.lower(): v for k, v in std_requirements.items()}

    ALL_CROPS = sorted(avg_requirements.keys())
    print(f"✅ Loaded {len(ALL_CROPS)} crops.")
except:
    avg_requirements = {}
    std_requirements = {}
    ALL_CROPS = []
    print("❌ Data not found.")


# ----------------------------------------------------
# 3. CROP SCORING ENGINE
# ----------------------------------------------------
def compute_crop_scores(N, P, K, ph):
    """
    Scores every crop in avg_requirements against the given slurry values.
    """
    if not avg_requirements:
        return []

    results = []
    weights = {"N": 1.0, "P": 1.0, "K": 1.0, "ph": 2.0}   # pH double-weighted
    total_weight = sum(weights.values())
    epsilon = 1e-6   # prevents division by zero

    for crop, ideal in avg_requirements.items():
        std = std_requirements.get(crop, {"N": 1, "P": 1, "K": 1, "ph": 0.5})

        actual = {"N": N, "P": P, "K": K, "ph": ph}
        weighted_score = 0.0

        gap = {}
        for nutrient, w in weights.items():
            ideal_val = ideal[nutrient]
            actual_val = actual[nutrient]
            sigma = max(std.get(nutrient, 1.0), epsilon)

            # Normalised absolute deviation (in units of std)
            norm_dev = abs(actual_val - ideal_val) / sigma

            nutrient_score = 100.0 * np.exp(-0.5 * (norm_dev ** 2))

            weighted_score += w * nutrient_score
            gap[nutrient] = round(actual_val - ideal_val, 2)

        match_score = round(weighted_score / total_weight, 1)

        results.append({
            "crop": crop,
            "match_score": match_score,
            "ideal": {k: round(v, 2) for k, v in ideal.items()},
            "gap": gap,
        })

    # Sort by match score descending
    results.sort(key=lambda x: x["match_score"], reverse=True)
    return results


def get_top_crops(N, P, K, ph, top_n=10):
    """Returns the top N scored crops as a clean list."""
    all_scores = compute_crop_scores(N, P, K, ph)
    return all_scores[:top_n]


# ----------------------------------------------------
# 4. ROBUST AI GENERATOR
# ----------------------------------------------------
# ----------------------------------------------------
# 4. ROBUST AI GENERATOR
# ----------------------------------------------------
def generate_with_fallback(prompt, response_json=False):
    if not client:
        return None

    models_to_try = [
        "gemini-2.0-flash",
        "gemini-2.5-flash",
        "gemini-2.0-flash-exp",
        "gemini-2.5-pro",
        "gemini-2.5-flash-lite"
    ]

    last_error = None

    for model_name in models_to_try:
        try:
            config = None
            if response_json:
                config = types.GenerateContentConfig(response_mime_type="application/json")

            response = client.models.generate_content(
                model=model_name,
                contents=prompt,
                config=config
            )
            return response.text.strip()

        except Exception as e:
            # FIX: If it disconnects or crashes, log it and TRY THE NEXT MODEL!
            print(f"⚠️ API Error on {model_name}, trying next model... ({e})")
            last_error = e
            continue 

    print(f"❌ All AI models failed. Last error: {last_error}")
    return None

# ----------------------------------------------------
# 6. GUIDANCE LOGIC
# ----------------------------------------------------
def generate_comprehensive_guidance(crop, N, P, K, ph, ideal, language='English'):
    # Compute exact gaps: positive = excess in slurry, negative = deficit
    gap_N  = round(N  - ideal['N'],  2)
    gap_P  = round(P  - ideal['P'],  2)
    gap_K  = round(K  - ideal['K'],  2)
    gap_ph = round(ph - ideal['ph'], 2)

    prompt = f"""
You are a biogas slurry agronomist. Your ONLY job is to tell the farmer what to physically
add or remove from their current slurry to make it match the ideal values for {crop}.

CURRENT SLURRY (from hardware sensor):
  N  = {N}   |  Ideal N  = {ideal['N']}   |  Gap = {gap_N:+.2f}  ({'EXCESS' if gap_N > 0 else 'DEFICIT' if gap_N < 0 else 'OK'})
  P  = {P}   |  Ideal P  = {ideal['P']}   |  Gap = {gap_P:+.2f}  ({'EXCESS' if gap_P > 0 else 'DEFICIT' if gap_P < 0 else 'OK'})
  K  = {K}   |  Ideal K  = {ideal['K']}   |  Gap = {gap_K:+.2f}  ({'EXCESS' if gap_K > 0 else 'DEFICIT' if gap_K < 0 else 'OK'})
  pH = {ph}  |  Ideal pH = {ideal['ph']}  |  Gap = {gap_ph:+.2f}  ({'EXCESS' if gap_ph > 0 else 'DEFICIT' if gap_ph < 0 else 'OK'})

RULES:
- Only give advice for nutrients where Gap != 0.
- For DEFICIT nutrients: specify exactly what to ADD to the biogas slurry and how much per 100L.
- For EXCESS nutrients: specify how to dilute or what to avoid adding.
- For pH: specify lime (to raise) or organic acids/sulfur (to lower), with quantity per 100L.
- Do NOT give general farming advice. Only slurry adjustment steps.
- Be specific: use grams or ml per 100 litres of slurry as the unit.

Respond ONLY in this exact JSON format, using the bracketed placeholders to fill in your real analysis. Do NOT copy the placeholders exactly:
{{
  "crop_name": "{crop}",
  "current": {{"N": {N}, "P": {P}, "K": {K}, "ph": {ph}}},
  "ideal":   {{"N": {ideal['N']}, "P": {ideal['P']}, "K": {ideal['K']}, "ph": {ideal['ph']}}},
  "adjustments": [
    {{
      "nutrient": "<N, P, K, or ph>",
      "status": "<EXCESS or DEFICIT>",
      "gap": <numeric gap value>,
      "action": "<Short instruction, e.g., 'Add urea' or 'Dilute with water'>",
      "quantity_per_100L": "<Amount, e.g., '120g' or '10L'>",
      "reason": "<Brief explanation of why this fixes the gap>"
    }}
  ],
  "application_order": ["Step 1: ...", "Step 2: ..."],
  "warnings": ["Warning if any"]
}}
"""

    if language != 'English':
        prompt += f'\nTranslate all values (not keys) in the JSON into {language}.'

    text = generate_with_fallback(prompt, response_json=True)

    if not text:
        return {
            'crop_name': crop,
            'current': {'N': N, 'P': P, 'K': K, 'ph': ph},
            'ideal':   {'N': ideal['N'], 'P': ideal['P'], 'K': ideal['K'], 'ph': ideal['ph']},
            'adjustments': [],
            'application_order': [],
            'warnings': ['AI unavailable. Compare current vs ideal values manually.'],
            'error': 'All AI models failed'
        }

    try:
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()
        return json.loads(text)
    except:
        return {
            'crop_name': crop,
            'current': {'N': N, 'P': P, 'K': K, 'ph': ph},
            'ideal':   {'N': ideal['N'], 'P': ideal['P'], 'K': ideal['K'], 'ph': ideal['ph']},
            'adjustments': [],
            'application_order': [],
            'warnings': [text],
            'error': 'JSON Parse Error'
        }


# ----------------------------------------------------
# 7. API ENDPOINTS
# ----------------------------------------------------

@app.route("/live_hardware_data", methods=["GET"])
def live_hardware_data():
    """Returns the real-time Arduino sensor values."""
    return jsonify({"status": "success", "data": LATEST_SENSOR_DATA})


@app.route("/calculate_methane", methods=["POST"])
async def calculate_methane():
    try:
        data = request.get_json()
        family_members = int(data.get("family_members", 4))
        current_methane = float(data.get("current_methane", 0))

        prompt = f"""
        Act as a biogas energy expert.
        A household has {family_members} family members.
        Their biogas plant's current methane reading is {current_methane} ppm.

        1. Calculate the ideal target methane concentration (in ppm) required for their daily cooking needs.
        2. If the current reading is lower than the target, estimate exactly how much mixed organic/food waste
           (in kg) they need to add to the digestate to bridge this gap.

        Provide the output strictly in JSON format:
        {{
          "family_size": {family_members},
          "target_methane_ppm": <realistic number between 4000 and 9000 based on family size>,
          "shortfall_ppm": <target - current, or 0 if target is met>,
          "waste_to_add_kg": <estimated kg of waste needed (number), or 0 if target is met>,
          "ai_advice": "Brief 1-sentence explanation of what to add to the digester."
        }}
        """

        text = await asyncio.to_thread(generate_with_fallback, prompt, True)

        if text:
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0].strip()
            elif "```" in text:
                text = text.split("```")[1].split("```")[0].strip()
            result = json.loads(text)
        else:
            result = {"error": "AI models failed."}

        return jsonify({"status": "success", "data": result})

    except Exception as e:
        print(f"Error calculating methane: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/analyze_slurry", methods=["POST"])
async def analyze_slurry():
    try:
        data = request.get_json()
        # Uses explicit fallback to 0.0 so no fake defaults are ever passed
        N = float(data.get("N", 0.0))
        P = float(data.get("P", 0.0))
        K = float(data.get("K", 0.0))
        ph = float(data.get("ph", 0.0))
        methane = float(data.get("methane", 0.0))
        temperature = float(data.get("temperature", 38.0))
        language = data.get("language", "English")
        top_n = int(data.get("top_n", 10))

        ranked_crops = get_top_crops(N, P, K, ph, top_n=top_n)

        if RF_model:
            df_in = pd.DataFrame([[N, P, K, ph]], columns=["N", "P", "K", "ph"])
            ml_top_crop = str(RF_model.predict(df_in)[0]).lower()
        else:
            ml_top_crop = ranked_crops[0]["crop"] if ranked_crops else "rice"

        user_crop = data.get("selected_crop")
        if user_crop:
            target_crop = user_crop.lower()
        else:
            target_crop = ranked_crops[0]["crop"] if ranked_crops else ml_top_crop

        ideal = avg_requirements.get(target_crop, {'N': 50, 'P': 50, 'K': 50, 'ph': 6.5})

        guidance_data = await asyncio.to_thread(
            generate_comprehensive_guidance, target_crop, N, P, K, ph, ideal, language
        )

        if language != 'English' and 'error' not in guidance_data:
            guidance_data = await asyncio.to_thread(translate_guidance, guidance_data, language)

        target_score_entry = next(
            (r for r in compute_crop_scores(N, P, K, ph) if r["crop"] == target_crop),
            None
        )
        suitability_score = target_score_entry["match_score"] if target_score_entry else 0.0

        return jsonify({
            "status": "success",
            "sensor_data": {
                "N": N, "P": P, "K": K, "ph": ph,
                "methane": methane, "temperature": temperature
            },
            "ml_recommendation": {"crop": ml_top_crop},
            "ranked_crops": ranked_crops,
            "crop_options": {
                "recommended": ml_top_crop,
                "similar_crops": [r["crop"] for r in ranked_crops],
                "all_available": ALL_CROPS
            },
            "selected_crop": target_crop,
            "ideal_values": ideal,
            "ai_guidance": guidance_data,
            "suitability_score": suitability_score,
            "methane_analysis": {
                "status": "optimal" if methane > 55 else "low",
                "value": methane
            },
            "language": language
        })

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/get_crops", methods=["GET"])
def get_crops():
    return jsonify({"status": "success", "crops": ALL_CROPS})


@app.route("/get_crop_scores", methods=["POST"])
def get_crop_scores():
    try:
        data = request.get_json()
        N = float(data.get("N", 0))
        P = float(data.get("P", 0))
        K = float(data.get("K", 0))
        ph = float(data.get("ph", 0.0))
        top_n = int(data.get("top_n", len(ALL_CROPS)))

        ranked = get_top_crops(N, P, K, ph, top_n=top_n)
        return jsonify({"status": "success", "ranked_crops": ranked, "total": len(ranked)})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/methane_guidance", methods=["POST"])
async def methane_guidance():
    data = request.get_json()
    prompt = (
        f"How to increase methane in biogas plant? "
        f"Current: {data.get('current_methane')}% Temp: {data.get('temperature')}C. JSON format."
    )
    text = await asyncio.to_thread(generate_with_fallback, prompt, True)

    try:
        if "```" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        guidance = json.loads(text)
    except:
        guidance = {"advice": text}

    return jsonify({"status": "success", "guidance": guidance})


@app.route("/farmer_chat", methods=["POST"])
async def farmer_chat():
    data = request.get_json()
    question = data.get("question", "")
    context = data.get("context", {})

    prompt = f"Context: {json.dumps(context)}. Question: {question}. Short practical answer."
    answer = await asyncio.to_thread(generate_with_fallback, prompt, False)

    if not answer:
        answer = "I'm having trouble connecting right now. Please try again."

    return jsonify({"status": "success", "answer": answer})


if __name__ == "__main__":
    threading.Thread(target=read_from_arduino, daemon=True).start()
    app.run(host="0.0.0.0", port=8000, debug=True, use_reloader=False)