# 🌾 RiceLeaf-CNN-ViT-Classification

## 🧠 CNN vs Vision Transformer: Empirical Analysis for Rice Leaf Disease Classification

This repository contains the implementation of our research on **rice leaf disease classification** using deep learning and transformer-based models. The study compares **Convolutional Neural Networks (CNNs)** and **Vision Transformers (ViT)** under low-resource agricultural settings.

---

## 📄 Publication Status

This work has been **accepted and presented** at International Conference on Electrical, Computer and Communication Technologies (ECCT 2026) and will be published soon in indexed proceedings.

> *Is CNN Dead? A Comprehensive Empirical Analysis of Convolutional Neural Networks, Ensemble Methods, and Vision Transformers for Rice Leaf Disease Classification in Low-Resource Agricultural Settings*

---

## 🎯 Research Objectives

- Evaluate CNN architectures vs Vision Transformers
- Study ensemble learning performance in agriculture image classification
- Analyze low-resource deployment feasibility
- Provide explainable AI visualizations

---

## 🧪 Models Used

### 🔷 CNN Models
- MobileNetV2 (Transfer Learning)
- EfficientNetB0 (Transfer Learning)
- Custom CNN Ensemble

### 🔷 Vision Transformer
- Vision Transformer (ViT)

---

## ⚙️ Ensemble Methods

- Soft Voting
- Weighted Averaging
- Stacking (Logistic Regression)

---

## 📊 Dataset

- 4,835 images
- 7 rice leaf disease/health classes
- Real-world field dataset
- Augmented for generalization

---

## 📈 Evaluation Metrics

- Accuracy
- Precision
- Recall
- F1-score
- AUC-ROC
- Precision-Recall Curve

---

## 🧠 Explainable AI (XAI)

- Grad-CAM
- Grad-CAM++
- LIME
- SHAP
- Attention Rollout (ViT)

---

## 🏆 Key Results

- Best model: CNN Ensemble (Stacking)
- Achieved **~94.88% accuracy**
- ViT baseline: ~77.10% accuracy
- CNN + Transfer Learning performs better in low-data settings
- Strong improvement using augmentation and ensemble learning

---
