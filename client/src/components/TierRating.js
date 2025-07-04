import React from 'react';
import './TierRating.css';

function TierRating({ rating }) {
  if (!rating) {
    return <div className="tier-rating">No tier data</div>;
  }

  const stars = Array(5).fill(0).map((_, i) => i < rating.rating);

  return (
    <div className="tier-rating">
      <div className={`tier-badge tier-${rating.tier || 'D'}`}>
        <span className="tier-letter">{rating.tier || 'D'}</span>
        <span className="tier-label">TIER</span>
      </div>

      <div className="rating-details">
        <div className="overall-score">
          <span className="score-label">Overall Score</span>
          <span className="score-value">{rating.score || 0}/100</span>
        </div>

        <div className="star-rating">
          {stars.map((filled, i) => (
            <span key={i} className={`star ${filled ? 'filled' : ''}`}>
              ★
            </span>
          ))}
        </div>

        {rating.details && (
          <div className="score-breakdown">
            <div className="score-item">
              <span className="item-label">Base Stats</span>
              <div className="item-bar">
                <div 
                  className="item-fill"
                  style={{ width: `${rating.details.bst || 0}%` }}
                />
              </div>
            </div>
            <div className="score-item">
              <span className="item-label">HP</span>
              <div className="item-bar">
                <div 
                  className="item-fill"
                  style={{ width: `${Math.min(rating.details.hp || 0, 100)}%` }}
                />
              </div>
            </div>
            <div className="score-item">
              <span className="item-label">Speed</span>
              <div className="item-bar">
                <div 
                  className="item-fill"
                  style={{ width: `${Math.min(rating.details.speed || 0, 100)}%` }}
                />
              </div>
            </div>
            <div className="score-item">
              <span className="item-label">Defense</span>
              <div className="item-bar">
                <div 
                  className="item-fill"
                  style={{ width: `${Math.min(rating.details.defense || 0, 100)}%` }}
                />
              </div>
            </div>
            <div className="score-item">
              <span className="item-label">Moves</span>
              <div className="item-bar">
                <div 
                  className="item-fill"
                  style={{ width: `${rating.details.moves || 0}%` }}
                />
              </div>
            </div>
            <div className="score-item">
              <span className="item-label">Type Defense</span>
              <div className="item-bar">
                <div 
                  className="item-fill"
                  style={{ width: `${rating.details.typing || 0}%` }}
                />
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default TierRating;