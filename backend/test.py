import joblib
import pandas as pd
import os

# Ensure this matches your exact model file name
MODEL_FILE = "crop_recommender_model_FINAL_FIX_NEW.pkl"

def run_test():
    print("=========================================")
    print(f"   TESTING ML MODEL: {MODEL_FILE}")
    print("=========================================")

    # 1. Check if the file exists
    if not os.path.exists(MODEL_FILE):
        print(f"\n❌ ERROR: Cannot find '{MODEL_FILE}'.")
        print("Make sure the file is in the same folder as this script!")
        return

    # 2. Try to load the model into memory
    try:
        print("\n⏳ Loading model...")
        model = joblib.load(MODEL_FILE)
        print("✅ Model loaded successfully!")
    except Exception as e:
        print(f"\n❌ ERROR LOADING MODEL: {e}")
        print("-> This usually means you have a version mismatch (e.g., your scikit-learn version is different than what was used to train the model).")
        return

    # 3. Create dummy data formatted EXACTLY how the backend does it
    try:
        print("\n⏳ Preparing test data (N=45, P=20, K=35, ph=7.0)...")
        # Notice the lowercase 'ph' - this must match your training data columns
        test_df = pd.DataFrame([[45, 20, 35, 7.0]], columns=["N", "P", "K", "ph"])
        
        # 4. Run the prediction
        print("⏳ Running prediction...")
        prediction = model.predict(test_df)
        
        print("\n🎉 SUCCESS! IT WORKS!")
        print(f"🌱 The model predicts: {prediction[0].upper()}")
        
    except Exception as e:
        print(f"\n❌ ERROR DURING PREDICTION: {e}")
        print("-> This usually happens if the column names (N, P, K, ph) don't exactly match the feature names the model was originally trained on.")

if __name__ == "__main__":
    run_test()