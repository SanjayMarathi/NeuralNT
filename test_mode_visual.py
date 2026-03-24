import torch
import torchvision
import torchvision.transforms as transforms
import matplotlib.pyplot as plt
import numpy as np

# -----------------------------
# 1️⃣ Device
# -----------------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# -----------------------------
# 2️⃣ Load Model (PyTorch 2.6 fix)
# -----------------------------
MODEL_PATH = "trained_model.pt"

model = torch.load(
    MODEL_PATH,
    map_location=device,
    weights_only=False  # IMPORTANT for full model load
)

model.to(device)
model.eval()

print("✅ Model loaded successfully.\n")

# -----------------------------
# 3️⃣ CIFAR-10 Test Dataset
# -----------------------------
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5, 0.5, 0.5),
                         (0.5, 0.5, 0.5))
])

testset = torchvision.datasets.CIFAR10(
    root="./data",
    train=False,
    download=True,
    transform=transform
)

testloader = torch.utils.data.DataLoader(
    testset,
    batch_size=8,
    shuffle=True
)

classes = testset.classes

# -----------------------------
# 4️⃣ Get Batch
# -----------------------------
images, labels = next(iter(testloader))
images, labels = images.to(device), labels.to(device)

# -----------------------------
# 5️⃣ Inference
# -----------------------------
with torch.no_grad():
    outputs = model(images)
    probabilities = torch.softmax(outputs, dim=1)
    confidence, predicted = torch.max(probabilities, 1)

# -----------------------------
# 6️⃣ Unnormalize for Display
# -----------------------------
images = images.cpu()
labels = labels.cpu()
predicted = predicted.cpu()
confidence = confidence.cpu()

def imshow(img):
    img = img / 2 + 0.5  # unnormalize
    npimg = img.numpy()
    return np.transpose(npimg, (1, 2, 0))

# -----------------------------
# 7️⃣ Plot Images
# -----------------------------
plt.figure(figsize=(12, 6))

correct = 0

for i in range(len(images)):
    plt.subplot(2, 4, i + 1)
    plt.imshow(imshow(images[i]))
    plt.axis("off")

    true_label = classes[labels[i]]
    pred_label = classes[predicted[i]]
    conf = confidence[i].item() * 100

    if predicted[i] == labels[i]:
        title_color = "green"
        correct += 1
    else:
        title_color = "red"

    plt.title(
        f"T: {true_label}\nP: {pred_label}\n{conf:.1f}%",
        color=title_color,
        fontsize=9
    )

accuracy = correct / len(images)

plt.suptitle(f"Batch Accuracy: {accuracy*100:.2f}%", fontsize=14)
plt.tight_layout()
plt.show()