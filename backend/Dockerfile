# Use an official Python runtime as a parent image
# We choose 3.11-slim for a smaller, faster deployment image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file first to leverage Docker caching
COPY requirements.txt .

# Install the dependencies from requirements.txt
# --no-cache-dir reduces the image size
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container
# This includes app.py, the model file (.pkl), and the dataset (.csv)
COPY . /app

# Expose the port the application will run on (Standard for web services)
EXPOSE 8080

# Set the default command to run the FastAPI app
# Cloud Run uses port 8080 internally, and 0.0.0.0 listens on all available interfaces
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
