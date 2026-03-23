import os
import shutil
import torch
import torch.nn as nn
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from PIL import Image
from torchvision import transforms
import uvicorn
import json
import io
from datetime import datetime
import torchvision.datasets
import torchvision.transforms
import torchvision
from layers import add_layer, update_layer, delete_layer, reset_layers, layer_configs, update_architecture_text
from training import train_model_with_default_path

app = FastAPI(
    title="NeuralNT Backend API",
    description="API for training and testing neural networks",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global state for training
training_state = {
    "is_training": False,
    "progress": 0,
    "logs": [],
    "current_epoch": 0,
    "total_epochs": 0
}

class LayerInput(BaseModel):
    layer_type: str
    in_dim: Optional[str] = ""
    out_dim: Optional[str] = ""

class TrainingConfig(BaseModel):
    loss_name: str
    opt_name: str
    lr: float
    batch_size: int
    image_size: int
    epochs: int
    num_channels: int

# --- HEALTH & STATUS ENDPOINTS ---

@app.get("/health")
def health_check():
    """Check if backend is running"""
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.get("/status")
def get_status():
    """Get current system status"""
    device = "GPU" if torch.cuda.is_available() else "CPU"
    return {
        "device": device,
        "torch_version": torch.__version__,
        "model_exists": os.path.exists(os.path.join("outputs", "trained_model.pt")),
        "training_active": training_state["is_training"]
    }

@app.get("/training-status")
def get_training_status():
    """Get current training progress"""
    return {
        "is_training": training_state["is_training"],
        "progress": training_state["progress"],
        "current_epoch": training_state["current_epoch"],
        "total_epochs": training_state["total_epochs"],
        "logs": training_state["logs"][-10:]  # Last 10 log entries
    }

# --- ARCHITECTURE ENDPOINTS ---

@app.get("/architecture")
def get_architecture():
    """Get the current model architecture"""
    try:
        return {"text": update_architecture_text(), "layers": layer_configs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching architecture: {str(e)}")

@app.post("/add_layer")
def api_add_layer(layer: LayerInput):
    """Add a layer to the model"""
    try:
        res = add_layer(layer.layer_type, layer.in_dim, layer.out_dim)
        return {"success": True, "architecture": res}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error adding layer: {str(e)}")

@app.post("/reset")
def api_reset():
    """Reset all layers"""
    try:
        reset_layers()
        return {"status": "reset", "success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error resetting: {str(e)}")

# --- TRAINING ENDPOINTS ---

@app.post("/train")
async def api_train(
    loss_name: str = Form(...),
    opt_name: str = Form(...),
    lr: str = Form(...),
    batch_size: str = Form(...),
    image_size: str = Form(...),
    epochs: str = Form(...),
    num_channels: int = Form(...),
    dataset: UploadFile = File(...)
):
    """Train the model with provided dataset (ZIP file)"""
    
    if training_state["is_training"]:
        raise HTTPException(status_code=409, detail="Training already in progress")
    
    # Validate file extension
    if not dataset.filename.endswith('.zip'):
        raise HTTPException(status_code=400, detail="Dataset must be a ZIP file")
    
    temp_file = f"temp_{datetime.now().timestamp()}_{dataset.filename}"
    training_state["is_training"] = True
    training_state["logs"] = []
    training_state["progress"] = 0
    
    try:
        # Save uploaded file
        with open(temp_file, "wb") as buffer:
            content = await dataset.read()
            buffer.write(content)
        
        training_state["logs"].append("Dataset uploaded successfully")
        
        results = None
        epoch_num = 0
        total_ep = int(epochs)
        training_state["total_epochs"] = total_ep
        
        for update in train_model_with_default_path(
            loss_name, opt_name, lr, batch_size, image_size,
            temp_file, "", epochs, num_channels,
            False, "300", "10"
        ):
            results = update
            epoch_num += 1
            training_state["current_epoch"] = epoch_num
            training_state["progress"] = int((epoch_num / total_ep) * 100)
            training_state["logs"].append(f"Epoch {epoch_num}/{total_ep} completed")

        training_state["logs"].append("Training completed successfully")
        
        return {
            "success": True,
            "loss_plot": results[0] if results else None,
            "logs": results[4] if results else "Training completed"
        }
        
    except Exception as e:
        training_state["logs"].append(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Training error: {str(e)}")
        
    finally:
        training_state["is_training"] = False
        if os.path.exists(temp_file):
            os.remove(temp_file)

# --- PREDICTION ENDPOINTS ---

@app.post("/predict")
async def api_predict(
    image: UploadFile = File(...),
    image_size: int = Form(32)
):
    """Run inference on an uploaded image"""
    
    model_path = os.path.join("outputs", "trained_model.pt")
    if not os.path.exists(model_path):
        raise HTTPException(status_code=400, detail="No trained model found. Train first!")
    
    # Validate image file mime type when possible
    if image.content_type is not None and image.content_type != "" and not image.content_type.startswith('image/'):
        if image.content_type != 'application/octet-stream':
            raise HTTPException(status_code=400, detail="File must be an image")

    try:
        # Load the model
        model = torch.load(model_path, map_location=torch.device('cpu'), weights_only=False)
        model.eval()

        # Prepare the image
        content = await image.read()
        try:
            img = Image.open(io.BytesIO(content)).convert('RGB')
        except Exception:
            raise HTTPException(status_code=400, detail="Uploaded file is not a valid image")

        # Validate image size
        if img.size[0] < 10 or img.size[1] < 10:
            raise ValueError("Image too small. Minimum 10x10 pixels required")
        
        transform = transforms.Compose([
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])
        ])
        img_tensor = transform(img).unsqueeze(0)

        # Predict
        with torch.no_grad():
            output = model(img_tensor)
            probabilities = torch.nn.functional.softmax(output[0], dim=0)
            confidence, class_idx = torch.max(probabilities, 0)

        # CIFAR-10 labels (can be extended)
        labels = ["Airplane", "Automobile", "Bird", "Cat", "Deer", "Dog", "Frog", "Horse", "Ship", "Truck"]

        return {
            "success": True,
            "prediction": labels[class_idx.item()] if class_idx.item() < len(labels) else f"Class {class_idx.item()}",
            "confidence": f"{confidence.item() * 100:.2f}%",
            "class_index": class_idx.item()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")

@app.post("/batch-predict")
async def batch_predict(
    images: List[UploadFile] = File(...),
    image_size: int = Form(32)
):
    """Run inference on multiple images"""
    
    model_path = os.path.join("outputs", "trained_model.pt")
    if not os.path.exists(model_path):
        raise HTTPException(status_code=400, detail="No trained model found. Train first!")

    try:
        model = torch.load(model_path, map_location=torch.device('cpu'), weights_only=False)
        model.eval()
        
        results = []
        labels = ["Airplane", "Automobile", "Bird", "Cat", "Deer", "Dog", "Frog", "Horse", "Ship", "Truck"]
        
        for image in images:
            try:
                if image.content_type is not None and image.content_type != "" and not image.content_type.startswith('image/'):
                    if image.content_type != 'application/octet-stream':
                        raise ValueError("File must be an image")

                content = await image.read()
                try:
                    img = Image.open(io.BytesIO(content)).convert('RGB')
                except Exception:
                    raise ValueError("Uploaded file is not a valid image")

                transform = transforms.Compose([
                    transforms.Resize((image_size, image_size)),
                    transforms.ToTensor(),
                    transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])
                ])
                img_tensor = transform(img).unsqueeze(0)
                
                with torch.no_grad():
                    output = model(img_tensor)
                    probabilities = torch.nn.functional.softmax(output[0], dim=0)
                    confidence, class_idx = torch.max(probabilities, 0)
                
                results.append({
                    "filename": image.filename,
                    "prediction": labels[class_idx.item()] if class_idx.item() < len(labels) else f"Class {class_idx.item()}",
                    "confidence": f"{confidence.item() * 100:.2f}%"
                })
            except Exception as e:
                results.append({
                    "filename": image.filename,
                    "error": str(e)
                })
        
        return {
            "success": True,
            "total_images": len(images),
            "results": results
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Batch prediction error: {str(e)}")

@app.post("/cifar-test")
def api_cifar_test(image_size: int = Form(32), batch_size: int = Form(8)):
    model_path = os.path.join("outputs", "trained_model.pt")
    if not os.path.exists(model_path):
        raise HTTPException(status_code=400, detail="No trained model found. Train first!")

    try:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        model = torch.load(model_path, map_location=device, weights_only=False)
        model.to(device)
        model.eval()

        transform = transforms.Compose([
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
        ])

        testset = torchvision.datasets.CIFAR10(
            root="./data",
            train=False,
            download=True,
            transform=transform
        )
        testloader = torch.utils.data.DataLoader(testset, batch_size=batch_size, shuffle=False)

        classes = testset.classes
        total = 0
        correct = 0
        preview = []

        # use one batch to mirror visual script
        for images, labels in testloader:
            images, labels = images.to(device), labels.to(device)
            with torch.no_grad():
                outputs = model(images)
                probs = torch.softmax(outputs, dim=1)
                _, predicted = torch.max(probs, 1)

            total += labels.size(0)
            correct += (predicted == labels).sum().item()

            if len(preview) < 8:
                for i in range(min(8 - len(preview), labels.size(0))):
                    preview.append({
                        "true": classes[labels[i].item()],
                        "predicted": classes[predicted[i].item()],
                        "confidence": float(torch.max(probs[i]).item())
                    })
            break

        accuracy = correct / total if total > 0 else 0.0

        return {
            "success": True,
            "batch_accuracy": f"{accuracy * 100:.2f}%",
            "total_tested": total,
            "correct": correct,
            "preview": preview
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"CIFAR test error: {exc}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
