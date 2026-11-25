cam = ipcam('http://10.0.222.157:8080/video');
img = snapshot(cam);
imshow(img)