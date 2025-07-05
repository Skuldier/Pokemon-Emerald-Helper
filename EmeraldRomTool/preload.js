// preload.js - Secure API bridge
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  selectRomFile: () => ipcRenderer.invoke('select-rom-file'),
  saveFile: (filename, content) => ipcRenderer.invoke('save-file', filename, content)
});

// Updated React component to use Electron APIs
// Add this to your React component:

const useElectronAPI = () => {
  const selectRomFile = async () => {
    if (window.electronAPI) {
      return await window.electronAPI.selectRomFile();
    }
    return null;
  };
  
  const saveFile = async (filename, content) => {
    if (window.electronAPI) {
      return await window.electronAPI.saveFile(filename, content);
    }
    
    // Fallback for web
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
    return true;
  };
  
  return { selectRomFile, saveFile };
};