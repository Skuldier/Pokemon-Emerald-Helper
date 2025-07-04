import React from 'react';
import './TierRating.css';

function TierRating({ rating }) {
  const stars = Array(5).fill(0).map((_, i) => i < rating.rating);

  return (
    <div className="tier-rating">
      <div className={`tier-badge tier-${rating.tier}`}>
        <span className="tier-letter">{rating.tier}</span>
        <span className="tier-label">TIER</span>
      </div>

      <div className="rating-details">
        <div className="overall-score">
          <span className="score-label">Overall Score</span>
          <span className="score-value">{rating.score}/100</span>
        </div>

        <div className="star-rating">
          {stars.map((filled, i) => (
            <span key={i} className={`star ${filled ? 'filled' : ''}`}>
              ★
            </span>
          ))}
        </div>

        <div className="score-breakdown">
          <div className="score-item">
            <span className="item-label">Base Stats</span>
            <div className="item-bar">
              <div 
                className="item-fill"
                style={{ width: `${rating.details.bst}%` }}
              />
            </div>
          </div>
          <div className="score-item">
            <span className="item-label">HP</span>
            <div className="item-bar">
              <div 
                className="item-fill"
                style={{ width: `${Math.min(rating.details.hp, 100)}%` }}
              />
            </div>
          </div>
          <div className="score-item">
            <span className="item-label">Speed</span>
            <div className="item-bar">
              <div 
                className="item-fill"
                style={{ width: `${Math.min(rating.details.speed, 100)}%` }}
              />
            </div>
          </div>
          <div className="score-item">
            <span className="item-label">Defense</span>
            <div className="item-bar">
              <div 
                className="item-fill"
                style={{ width: `${Math.min(rating.details.defense, 100)}%` }}
              />
            </div>
          </div>
          <div className="score-item">
            <span className="item-label">Moves</span>
            <div className="item-bar">
              <div 
                className="item-fill"
                style={{ width: `${rating.details.moves}%` }}
              />
            </div>
          </div>
          <div className="score-item">
            <span className="item-label">Type Defense</span>
            <div className="item-bar">
              <div 
                className="item-fill"
                style={{ width: `${rating.details.typing}%` }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default TierRating;
