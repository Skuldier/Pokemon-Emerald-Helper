// client/src/components/ROMUpload.js
import React, { useState } from 'react';
import './ROMUpload.css';

function ROMUpload({ onAnalysisComplete }) {
  const [uploading, setUploading] = useState(false);
  const [analysis, setAnalysis] = useState(null);
  const [error, setError] = useState(null);
  const [dragActive, setDragActive] = useState(false);

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileInput = (e) => {
    if (e.target.files && e.target.files[0]) {
      handleFile(e.target.files[0]);
    }
  };

  const handleFile = async (file) => {
    // Validate file
    if (!file.name.endsWith('.gba')) {
      setError('Please upload a .gba ROM file');
      return;
    }

    if (file.size > 32 * 1024 * 1024) { // 32MB max
      setError('File too large. Maximum size is 32MB');
      return;
    }

    setUploading(true);
    setError(null);
    setAnalysis(null);

    const formData = new FormData();
    formData.append('rom', file);

    try {
      const response = await fetch('http://localhost:3001/api/analyze-rom', {
        method: 'POST',
        body: formData
      });

      if (!response.ok) {
        throw new Error(`Analysis failed: ${response.statusText}`);
      }

      const result = await response.json();
      setAnalysis(result);
      
      if (onAnalysisComplete) {
        onAnalysisComplete(result);
      }
    } catch (err) {
      setError(err.message);
      console.error('ROM analysis error:', err);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="rom-upload-container">
      <h3>ROM Analysis Tool</h3>
      <p className="upload-description">
        Upload your patched Pokemon Emerald ROM to analyze memory modifications and optimize the companion tool.
      </p>

      <div 
        className={`upload-zone ${dragActive ? 'drag-active' : ''}`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <input
          type="file"
          id="rom-file"
          accept=".gba"
          onChange={handleFileInput}
          className="file-input"
          disabled={uploading}
        />
        <label htmlFor="rom-file" className="file-label">
          {uploading ? (
            <div className="uploading">
              <div className="spinner"></div>
              <span>Analyzing ROM...</span>
            </div>
          ) : (
            <>
              <div className="upload-icon">📁</div>
              <span>Drop your .gba ROM here or click to browse</span>
              <span className="file-hint">Pokemon Emerald ROM (patched or original)</span>
            </>
          )}
        </label>
      </div>

      {error && (
        <div className="error-message">
          ⚠️ {error}
        </div>
      )}

      {analysis && (
        <div className="analysis-results">
          <h4>Analysis Results</h4>
          
          <div className="result-section">
            <h5>ROM Information</h5>
            <div className="info-grid">
              <span>Game ID:</span>
              <span>{analysis.gameId || 'Unknown'}</span>
              <span>Version:</span>
              <span>{analysis.version || 'Unknown'}</span>
              <span>Size:</span>
              <span>{analysis.size ? `${(analysis.size / 1024 / 1024).toFixed(2)} MB` : 'Unknown'}</span>
            </div>
          </div>

          {analysis.dmaStatus && (
            <div className="result-section">
              <h5>DMA Protection Status</h5>
              <div className={`dma-status ${analysis.dmaStatus.disabled ? 'disabled' : 'active'}`}>
                {analysis.dmaStatus.disabled ? '✓ DMA Protection Disabled' : '⚠️ DMA Protection Active'}
              </div>
              {analysis.dmaStatus.pattern && analysis.dmaStatus.offset !== undefined && (
                <div className="pattern-info">
                  Pattern found at: 0x{analysis.dmaStatus.offset.toString(16).toUpperCase()}
                </div>
              )}
            </div>
          )}

          {analysis.memoryAddresses && Object.keys(analysis.memoryAddresses).length > 0 && (
            <div className="result-section">
              <h5>Detected Memory Addresses</h5>
              <div className="address-list">
                {Object.entries(analysis.memoryAddresses).map(([name, addr]) => (
                  <div key={name} className="address-item">
                    <span className="address-name">{name}:</span>
                    <span className="address-value">
                      {typeof addr === 'number' ? `0x${addr.toString(16).toUpperCase()}` : 'Invalid'}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {analysis.patches && analysis.patches.length > 0 && (
            <div className="result-section">
              <h5>Detected Patches</h5>
              <ul className="patch-list">
                {analysis.patches.map((patch, idx) => (
                  <li key={idx}>{patch}</li>
                ))}
              </ul>
            </div>
          )}

          <button 
            className="apply-button"
            onClick={() => onAnalysisComplete && onAnalysisComplete(analysis)}
          >
            Apply Analysis to Companion Tool
          </button>
        </div>
      )}
    </div>
  );
}

export default ROMUpload;