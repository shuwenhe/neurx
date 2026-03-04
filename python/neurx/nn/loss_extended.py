"""
Extended Loss Functions

Provides additional loss functions commonly used in deep learning.
Extends the base loss.py module with advanced loss functions.
"""

import numpy as np


# ============================================================================
# Focal Loss - for addressing class imbalance
# ============================================================================

def focal_loss(predictions, targets, alpha=0.25, gamma=2.0):
    """
    Focal Loss - addresses class imbalance by focusing on hard negatives
    
    Formula: FL(p_t) = -α * (1 - p_t)^γ * log(p_t)
    
    Args:
        predictions: Predicted probabilities [0, 1]
        targets: Ground truth binary labels {0, 1}
        alpha: Weighting factor (default 0.25)
        gamma: Focusing parameter (default 2.0)
        
    Returns:
        float: Focal loss value
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    # Clip predictions to prevent log(0)
    predictions = np.clip(predictions, 1e-7, 1 - 1e-7)
    
    # Focal loss for binary classification
    ce_loss = -targets * np.log(predictions) - (1 - targets) * np.log(1 - predictions)
    
    # Get probability of correct class
    p_t = np.where(targets == 1, predictions, 1 - predictions)
    
    # Apply focal term
    focal_weight = (1 - p_t) ** gamma
    focal = alpha * focal_weight * ce_loss
    
    return np.mean(focal)


def focal_loss_multi(predictions, targets, alpha=0.25, gamma=2.0):
    """
    Multi-class Focal Loss
    
    Args:
        predictions: Predicted probabilities (batch, num_classes) after softmax
        targets: Ground truth class indices (batch,)
        alpha: Weighting factor
        gamma: Focusing parameter
        
    Returns:
        float: Multi-class focal loss value
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.int32)
    
    batch_size = predictions.shape[0]
    
    # Clip predictions
    predictions = np.clip(predictions, 1e-7, 1 - 1e-7)
    
    # Get probabilities of target classes
    target_probs = predictions[np.arange(batch_size), targets]
    
    # Cross entropy
    ce_loss = -np.log(target_probs)
    
    # Focal term
    focal_weight = (1 - target_probs) ** gamma
    focal = alpha * focal_weight * ce_loss
    
    return np.mean(focal)


# ============================================================================
# Hinge Loss and Margin-based Losses
# ============================================================================

def hinge_loss(predictions, targets, margin=1.0):
    """
    Hinge Loss (SVM loss) - for binary classification
    
    Formula: L = max(0, margin - y * pred)
    where y ∈ {-1, 1}
    
    Args:
        predictions: Predicted values (can be any real number)
        targets: Ground truth {-1, 1}
        margin: Margin parameter (default 1.0)
        
    Returns:
        float: Hinge loss value
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    # Ensure targets are {-1, 1}
    targets = 2 * targets - 1  # Convert {0, 1} to {-1, 1}
    
    losses = np.maximum(0, margin - targets * predictions)
    return np.mean(losses)


def smooth_l1_loss(predictions, targets, beta=1.0):
    """
    Smooth L1 Loss (Huber Loss) - robust to outliers
    
    Formula:
    - if |x| <= β: 0.5 * x^2 / β
    - else: |x| - 0.5 * β
    
    Args:
        predictions: Predicted values
        targets: Ground truth values
        beta: Transition point (default 1.0)
        
    Returns:
        float: Smooth L1 loss value
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    diff = np.abs(predictions - targets)
    
    # Piecewise smooth L1
    smooth_l1 = np.where(
        diff <= beta,
        0.5 * (diff ** 2) / beta,
        diff - 0.5 * beta
    )
    
    return np.mean(smooth_l1)


def huber_loss(predictions, targets, delta=1.0):
    """
    Huber Loss - similar to smooth L1 but different formulation
    
    Args:
        predictions: Predicted values
        targets: Ground truth values
        delta: Threshold for L2/L1 transition (default 1.0)
        
    Returns:
        float: Huber loss value
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    diff = predictions - targets
    
    huber = np.where(
        np.abs(diff) <= delta,
        0.5 * (diff ** 2),
        delta * (np.abs(diff) - 0.5 * delta)
    )
    
    return np.mean(huber)


def margin_ranking_loss(predictions1, predictions2, targets, margin=1.0):
    """
    Margin Ranking Loss - for pairwise ranking
    
    Formula: L = max(0, -y * (pred1 - pred2) + margin)
    where y ∈ {-1, 1}
    
    Args:
        predictions1: Predictions for first item
        predictions2: Predictions for second item
        targets: Target {-1, 1} (1 if pred1 > pred2, -1 otherwise)
        margin: Margin (default 1.0)
        
    Returns:
        float: Margin ranking loss value
    """
    predictions1 = np.asarray(predictions1, dtype=np.float32)
    predictions2 = np.asarray(predictions2, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    losses = np.maximum(0, -targets * (predictions1 - predictions2) + margin)
    return np.mean(losses)


# ============================================================================
# Information-theoretic Losses
# ============================================================================

def kullback_leibler_divergence(predictions, targets):
    """
    Kullback-Leibler Divergence - measure of probability distribution difference
    
    Formula: KL(P || Q) = Σ P(x) * log(P(x) / Q(x))
    
    Args:
        predictions: Predicted probability distribution Q
        targets: Target probability distribution P
        
    Returns:
        float: KL divergence value
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    # Clip for numerical stability
    targets = np.clip(targets, 1e-7, 1.0)
    predictions = np.clip(predictions, 1e-7, 1.0)
    
    kl = np.sum(targets * np.log(targets / predictions), axis=-1)
    return np.mean(kl)


def jensen_shannon_divergence(predictions, targets):
    """
    Jensen-Shannon Divergence - symmetric version of KL divergence
    
    Formula: JS(P || Q) = 0.5 * KL(P || M) + 0.5 * KL(Q || M)
    where M = (P + Q) / 2
    
    Args:
        predictions: Predicted probability distribution
        targets: Target probability distribution
        
    Returns:
        float: Jensen-Shannon divergence value
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    # Clip for numerical stability
    predictions = np.clip(predictions, 1e-7, 1.0)
    targets = np.clip(targets, 1e-7, 1.0)
    
    # Midpoint distribution
    m = (predictions + targets) / 2
    
    # Jensen-Shannon
    js = 0.5 * np.sum(targets * np.log(targets / m), axis=-1) + \
         0.5 * np.sum(predictions * np.log(predictions / m), axis=-1)
    
    return np.mean(js)


def wasserstein_loss(predictions, targets):
    """
    Wasserstein Loss - measures distance between distributions
    
    Args:
        predictions: Predicted values
        targets: Target values
        
    Returns:
        float: Wasserstein distance (simplified version)
    """
    predictions = np.asarray(predictions, dtype=np.float32)
    targets = np.asarray(targets, dtype=np.float32)
    
    # Simple 1D Wasserstein
    return np.mean(np.abs(predictions - targets))


# ============================================================================
# Contrastive and Metric Learning Losses
# ============================================================================

def triplet_loss(anchor, positive, negative, margin=1.0):
    """
    Triplet Loss - for metric learning / siamese networks
    
    Formula: L = max(0, d(anchor, positive) - d(anchor, negative) + margin)
    
    Args:
        anchor: Anchor embeddings (batch, embed_dim)
        positive: Positive embeddings (batch, embed_dim)
        negative: Negative embeddings (batch, embed_dim)
        margin: Margin parameter (default 1.0)
        
    Returns:
        float: Triplet loss value
    """
    anchor = np.asarray(anchor, dtype=np.float32)
    positive = np.asarray(positive, dtype=np.float32)
    negative = np.asarray(negative, dtype=np.float32)
    
    # Euclidean distances
    pos_dist = np.sqrt(np.sum((anchor - positive) ** 2, axis=-1) + 1e-6)
    neg_dist = np.sqrt(np.sum((anchor - negative) ** 2, axis=-1) + 1e-6)
    
    # Triplet loss
    losses = np.maximum(0, pos_dist - neg_dist + margin)
    return np.mean(losses)


def contrastive_loss(embeddings1, embeddings2, labels, margin=1.0):
    """
    Contrastive Loss - for learning similarity between pairs
    
    Args:
        embeddings1: First set of embeddings
        embeddings2: Second set of embeddings
        labels: Binary labels (1 if similar, 0 if dissimilar)
        margin: Margin for dissimilar pairs (default 1.0)
        
    Returns:
        float: Contrastive loss value
    """
    embeddings1 = np.asarray(embeddings1, dtype=np.float32)
    embeddings2 = np.asarray(embeddings2, dtype=np.float32)
    labels = np.asarray(labels, dtype=np.float32)
    
    # Euclidean distance
    distances = np.sqrt(np.sum((embeddings1 - embeddings2) ** 2, axis=-1) + 1e-6)
    
    # Contrastive loss
    similar_loss = labels * (distances ** 2)
    dissimilar_loss = (1 - labels) * np.maximum(0, margin - distances) ** 2
    
    return np.mean(similar_loss + dissimilar_loss)


def ntxent_loss(embeddings, labels, temperature=0.07):
    """
    Normalized Temperature-scaled Cross Entropy Loss (NT-Xent)
    - Used in contrastive learning (SimCLR, etc.)
    
    Args:
        embeddings: Embeddings (batch_size, embed_dim)
        labels: Labels for grouping (batch_size,)
        temperature: Temperature parameter (default 0.07)
        
    Returns:
        float: NT-Xent loss value
    """
    embeddings = np.asarray(embeddings, dtype=np.float32)
    labels = np.asarray(labels, dtype=np.int32)
    
    batch_size = embeddings.shape[0]
    
    # Normalize embeddings
    embeddings = embeddings / (np.linalg.norm(embeddings, axis=-1, keepdims=True) + 1e-8)
    
    # Cosine similarity
    similarity = np.dot(embeddings, embeddings.T)
    similarity = similarity / temperature
    
    # Mask for positive pairs
    mask = labels[:, None] == labels[None, :]
    
    # Logits for numerator (positive pairs)
    pos_logits = similarity[mask].reshape(batch_size, -1)
    
    # Cross entropy
    logits_max = np.max(similarity, axis=-1, keepdims=True)
    similarity_exp = np.exp(similarity - logits_max)
    
    # Sum of all exponentials (denominator)
    denom = np.sum(similarity_exp, axis=-1)
    
    # Calculate NT-Xent loss
    log_prob = similarity - logits_max - np.log(denom[:, None])
    
    # Average positive log-probabilities
    loss = -np.mean(np.sum(log_prob * mask, axis=-1) / (np.sum(mask, axis=-1) - 1))
    
    return loss


# ============================================================================
# Other Specialized Losses
# ============================================================================

def center_loss(embeddings, labels, centers, alpha=0.5):
    """
    Center Loss - minimizes intra-class variance
    
    Args:
        embeddings: Embeddings (batch_size, embed_dim)
        labels: Class labels (batch_size,)
        centers: Class centers (num_classes, embed_dim)
        alpha: Loss weight (default 0.5)
        
    Returns:
        float: Center loss value
    """
    embeddings = np.asarray(embeddings, dtype=np.float32)
    labels = np.asarray(labels, dtype=np.int32)
    centers = np.asarray(centers, dtype=np.float32)
    
    # Get centers for each sample
    center_batch = centers[labels]
    
    # L2 distance to center
    dist = np.sqrt(np.sum((embeddings - center_batch) ** 2, axis=-1) + 1e-6)
    
    return alpha * np.mean(dist ** 2)


def arcface_loss(embeddings, labels, weights, s=64.0, m=0.5, num_classes=None):
    """
    ArcFace Loss - for face recognition (additive angular margin)
    
    Args:
        embeddings: Embeddings (batch_size, embed_dim)
        labels: Class labels (batch_size,)
        weights: Weight matrix (num_classes, embed_dim)
        s: Scale parameter (default 64.0)
        m: Angular margin (default 0.5)
        num_classes: Number of classes
        
    Returns:
        float: ArcFace loss value
    """
    embeddings = np.asarray(embeddings, dtype=np.float32)
    labels = np.asarray(labels, dtype=np.int32)
    weights = np.asarray(weights, dtype=np.float32)
    
    batch_size = embeddings.shape[0]
    
    # Normalize embeddings and weights
    embeddings_norm = embeddings / (np.linalg.norm(embeddings, axis=-1, keepdims=True) + 1e-8)
    weights_norm = weights / (np.linalg.norm(weights, axis=-1, keepdims=True) + 1e-8)
    
    # Cosine similarity
    cos_theta = np.dot(embeddings_norm, weights_norm.T)
    cos_theta = np.clip(cos_theta, -1.0, 1.0)
    
    # Add angular margin
    theta = np.arccos(cos_theta)
    theta_m = theta + m
    cos_theta_m = np.cos(theta_m)
    
    # Scale and compute loss
    logits = s * cos_theta_m
    
    # CrossEntropy loss
    logits_max = np.max(logits, axis=-1, keepdims=True)
    logits_exp = np.exp(logits - logits_max)
    logits_sum = np.sum(logits_exp, axis=-1, keepdims=True)
    
    # Log-softmax
    log_softmax = logits - logits_max - np.log(logits_sum)
    
    # Extract loss for correct class
    loss = -log_softmax[np.arange(batch_size), labels]
    
    return np.mean(loss)


__all__ = [
    'focal_loss', 'focal_loss_multi',
    'hinge_loss', 'smooth_l1_loss', 'huber_loss', 'margin_ranking_loss',
    'kullback_leibler_divergence', 'jensen_shannon_divergence', 'wasserstein_loss',
    'triplet_loss', 'contrastive_loss', 'ntxent_loss',
    'center_loss', 'arcface_loss',
]
