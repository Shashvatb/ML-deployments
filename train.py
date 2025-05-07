from torch.utils.data import DataLoader, Dataset
from tqdm import tqdm

import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
import os
import pickle
import numpy as np


# Model definition
class Net(nn.Module):
    def __init__(self, epochs=100):
        super().__init__()
        self.criterion = nn.BCEWithLogitsLoss()
        self.epochs = epochs
        self.conv1 = nn.Conv2d(1, 4, 3)
        self.maxpool1 = nn.MaxPool2d(3, 3)
        self.conv2 = nn.Conv2d(4, 8, 3)
        self.maxpool2 = nn.MaxPool2d(3, 3)
        self.flatten_shape = None
        x = torch.randn([50,50]).view(-1,1,50,50)
        x = self.conv(x)
        self.fc1 = nn.Linear(self.flatten_shape, 128)
        self.fc2 = nn.Linear(128, 5)
    
    def conv(self, x):
        x = F.relu(self.conv1(x))
        x = self.maxpool1(x)
        x = F.relu(self.conv2(x))
        x = self.maxpool2(x)
        if self.flatten_shape is None:
            self.flatten_shape = x.shape[1] * x.shape[2] * x.shape[3]
            # print(x.shape)
            # print(self.flatten_shape)
        return x
    
    def forward(self, x):
        x = self.conv(x)
        x = x.view(-1, self.flatten_shape)
        x = F.relu(self.fc1(x))
        x = F.softmax(self.fc2(x), dim=1)
#         x = self.fc2(x)
        return x


# dataset class
class ImageData(Dataset):
    def __init__(self, data):
        self.x = torch.Tensor([i[0].astype(np.float32)/255.0 for i in data])
        self.y = torch.Tensor([i[1] for i in data])#.long()
        self.m = self.x.shape[0]
        
    def __getitem__(self, index):
        return self.x[index], self.y[index]
    
    def __len__(self):
        return self.m


# Training the model
def train(dataloader, model, optimizer):
    model.train()
    losses = []
    best_loss = 10000000000000.0
    for epoch in tqdm(range(model.epochs)):
        epoch_losses = []
        for i, (inputs, labels) in enumerate(dataloader):
            inputs = inputs.view(-1, 1, 50, 50).to(device)
            
            labels = labels.view(-1,5).to(device)   
#             print(labels)
            model.zero_grad()
            optimizer.zero_grad()
            y_hat = model.forward(inputs)
#             print(y_hat)
            loss = model.criterion(y_hat, labels)
            loss.backward()
            optimizer.step()
            epoch_losses.append(loss)
            if i % 16 == 0:
                losses.append(loss)
        epoch_losses = [i.cpu().detach() for i in epoch_losses]
        if np.mean(epoch_losses) < best_loss:
            torch.save(model.state_dict(), os.path.join(os.getcwd(), 'model.pth'))
            best_loss = np.mean(epoch_losses)
    return model, losses    


# Model Validation
def validate(model, dataloader):
    model.load_state_dict(torch.load('model.pth'))
    model.eval()
    correct = 0
    total = 0
    for i, (inputs, labels) in tqdm(enumerate(dataloader)):
        inputs = inputs.view(-1, 1, 50, 50).to(device)    
        labels = labels.view(-1,5).to(device)  
        
        y_hat = model.forward(inputs)
#         print(torch.sum(torch.argmax(y_hat, dim=1) == torch.argmax(labels, dim=1)))
#         print(torch.argmax(labels, dim=1))
#         break
        correct += torch.sum(torch.argmax(y_hat, dim=1) == torch.argmax(labels, dim=1))
#         print(correct)
        total += inputs.shape[0]
#         print(total)
    return correct.item()/total


if __name__ == '__main__':
    # init device
    device = torch.device('cuda') if torch.cuda.is_available() else torch.device('cpu')
    
    # init data
    data = pickle.load(open(os.path.join(os.getcwd(), 'train_data.pickle'),'rb'))
    data_train = data[:int(0.9*len(data))]
    data_val = data[int(0.9*len(data)):]

    # init train dataset and dataloader
    dataset_train = ImageData(data_train)
    dataloader_train = DataLoader(dataset_train, batch_size=32, shuffle=True)

    # init val dataset and dataloader
    dataset_val = ImageData(data_val)
    dataloader_val = DataLoader(dataset_val, batch_size=32)

    # init model
    model = Net().to(device)
    optimizer = optim.Adam(model.parameters())

    # train model
    model, losses = train(dataloader_train, model, optimizer)

    # Validate model
    metrics = validate(model, dataloader_val)
    print(metrics)




