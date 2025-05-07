from fastapi import FastAPI, File, UploadFile
from torchvision import transforms
from PIL import Image
from train import Net

import torch.optim as optim
import torch
import torch.nn as nn
import io


model = Net()
model.load_state_dict(torch.load('model.pth', map_location="cpu"))
model.eval()

app = FastAPI()

@app.get("/")
def test():
    return {'test': 'success'}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    image = Image.open(io.BytesIO(await file.read())).convert("RGB")
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor()
    ])
    input_tensor = transform(image).unsqueeze(0)
    with torch.no_grad():
        y_hat = model.forward(input_tensor)
        pred=  str(torch.argmax(y_hat, dim=1).item() + 1)
    return {"prediction": pred}