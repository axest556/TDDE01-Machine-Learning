#### INSTALL NECESSARY PACKAGES ####
install.packages("tree")
library(tree)
library(rpart)


#### TASK 2.1 - Divide the Data ####
# Load the data into a variable
data <- read.csv("Data/bank-full.csv", 
                 header = T, sep=";", 
                 stringsAsFactors = TRUE) # Note: read.csv2 takes the separator as ; as default

# Remove duration column from data set
data <- data[, !names(data) %in% c("duration")]

# Get the number of rows in the dataset
n <- dim(data)[1]

# Set a random seed for reproducibility
set.seed(12345)

# Partition 40% of the data for the training set
id <- sample(1:n, floor(n * 0.4))
train <- data[id, ]

# Partition 30% of the data for the validation set
id1 <- setdiff(1:n, id)
set.seed(12345)
id2 <- sample(id1, floor(n * 0.3))
valid <- data[id2, ]

# Use the rest for the test set
id3 <- setdiff(id1, id2)
test <- data[id3, ]




#### Task 2.2 - Different Decision Tree Models ####

# Model A - Default fit
fit_default <- tree(y ~ ., data = train)
train_pred_default <- predict(fit_default, train, type = "class") # Prediction on train data
valid_pred_default <- predict(fit_default, valid, type = "class") # Prediction on validation data

# Calculate misclassification errors
train_mis_default <- mean(train_pred_default != train$y) # 0.1048441
valid_mis_default <- mean(valid_pred_default != valid$y) # 0.1092679


# Model B - Smallest allowed node size = 7000
# This means that a node must have minimum 7000 observations in order to be able to split
# However, a split of 14'000 can be 10'000 to left and 4'000 to right

n_train <- dim(train)[1] # Nr of obeservations (rows) in train data

# Fit the model with a smallest allowed node size of 7000
fit_min_node <- tree(y ~ ., 
                     data = train, 
                     control = tree.control(nobs = n_train, minsize = 7000))  # Set the minimum node size to 7000

train_pred_min_node <- predict(fit_min_node, train, type = "class") # Prediction on train data
valid_pred_min_node <- predict(fit_min_node, valid, type = "class") # Prediction on validation data

# Calculate misclassification errors
train_mis_min_node <- mean(train_pred_min_node != train$y) # 0.1048441
valid_mis_min_node <- mean(valid_pred_min_node != valid$y) # 0.1092679


# Model C - Minimum deviance = 0.0005
# This parameter controls the minimum deviance for a node to be split further. 
# The lower the value, the more sensitive the tree will be to potential splits.

# Fit the tree model with a minimum deviance of 0.0005
fit_min_dev <- tree(y ~ ., 
                         data = train, 
                         control = tree.control(nobs = n_train, mindev = 0.0005))

train_pred_min_dev <- predict(fit_min_dev, train, type = "class") # Prediction on train data
valid_pred_min_dev <- predict(fit_min_dev, valid, type = "class") # Prediction on validation data

# Calculate misclassification errors
train_mis_min_dev <- mean(train_pred_min_dev != train$y) # 0.09400575
valid_mis_min_dev <- mean(valid_pred_min_dev != valid$y) # 0.1119221

# Visualize all trees
plot(fit_default)
text(fit_default, pretty = 0)
summary(fit_default)

plot(fit_min_node)
text(fit_min_node, pretty = 0)
summary(fit_min_node)

plot(fit_min_dev)
text(fit_min_dev, pretty = 0)
summary(fit_min_dev)




#### TASK 2.3 - Optimal Tree Depth (Number of Leaves) ####

# Clarification of Termnial Nodes, Leaves and Depth:
# Terminal nodes = Leaves = Final nodes in a decision tree with no further splits = Classification decisions
# Depth = Length of the longest path from the root node to a terminal node (leaf)


# Use model 2C
fit_full_tree <- fit_min_dev # Fitted with full depth from start = fully grown decision tree

# Create arrays to store deviance values for 1 to 50 terminal nodes (leaves)
trainDeviance <- rep(2,50)
validDeviance <- rep(2,50)

# Iterate over possible number of terminal nodes (leaves) from 1 to 50
for (i in 2:50) {
  # Prune the tree to have i terminal nodes
  prunedTree <- prune.tree(fit_full_tree, best = i) # best = nr of terminal nodes (or leaves)
  
  # Make predictions on validation data
  valid_pred <- predict(prunedTree, newdata = valid, type = "tree")
  
  # Store deviance values
  trainDeviance[i] = deviance(prunedTree)
  validDeviance[i] = deviance(valid_pred)
}

# Plot train and validation deviances on nr of terminal nodes (leaves)
plot(2:50, trainDeviance[2:50], type = "b", col = "red",
     ylim = c(min(c(trainDeviance[3:50], validDeviance[3:50])), max(c(trainDeviance, validDeviance))), # Size of y-axis
     xlab = "Number of Leaves", ylab = "Deviance", 
     main = "Deviance vs. Number of Leaves")
points(2:50, validDeviance[2:50], type = "b", col = "blue")
legend("topright", legend = c("Training Deviance", "Validation Deviance"), 
       col = c("red", "blue"), pch = 19)

# Find optimal number of leaves <==> where validDeviance is minimized
optimal_leaves <- which.min(validDeviance[2:50]) + 1 # Add 1 because starting from 2
optimal_leaves # 22

# Visualize tree with depth 22
optimalTree <- prune.tree(fit_full_tree, best = optimal_leaves)
plot(optimalTree)
text(optimalTree, pretty = 0)
summary(optimalTree)

# Most important variables for decision making in this tree (top nodes):
# poutcome, month, contact




#### TASK 2.4 - Confusion Matrix, Accuracy & F1 Score ####

# Confusion matrix based on test data
pred_test <- predict(optimalTree, newdata = test, type = "class") # Predictions on test set
confusion_matrix <- table(True = test$y, Predicted = pred_test)
print(confusion_matrix)

# Compute necessary variables
n_test <- dim(test)[1] # Nr of obeservations (rows) in train data
TP <- confusion_matrix["yes", "yes"] # True Positive. 214
TN <- confusion_matrix["no", "no"] # True Negative.   11872
FP <- confusion_matrix["no", "yes"] # False Positive  107
FN <- confusion_matrix["yes", "no"] # False Negative  1371

# Accuracy based on test data = (TP + TN) / n
accuracy <- (TP + TN) / n_test
accuracy # 0.8910351

# Precision, Recall, and F1 Score
precision <- TP / (TP + FP) # 0.6666667
recall <- TP / (TP + FN) # = True Positive Rates = sensitivity = recall = 0.1350157
F1 <- (2 * precision * recall) / (precision + recall)
F1 # 0.224554

# Accuracy does not take imbalanced classes into account, but F1 score does
# Imbalanced classes meaning very large number of 1 and very small number of 0

sum(test$y == "yes") # 1585 cases
sum(test$y == "no")  # 11979 cases

# F1 is preferre due to the class imbalance.


#### TASK 2.5 - Decision Tree Classification with Loss Matrix ####

# A loss matrix assign different penalties to various types of misclassifications

# Probabilities for classification on test data (Note: type = "vector")
pred_test <- as.matrix(predict(optimalTree, newdata = test, type = "vector"))
pred_test

# Custom Loss Matrix: TP=0, FN=5, FP=1, TN=0
loss_matrix <- pred_test %*% matrix(c(0, 1, 5, 0), nrow = 2, byrow = TRUE)

# Print loss matrix to verify correct setup
print(loss_matrix)

# Apply best (min) value on each row
best_index <- apply(loss_matrix, MARGIN = 1, FUN = which.min)

# Convert y variable to factor based on best index
pred = levels(test$y)[best_index]

# New confusion matrix
confusion_matrix <- table(True = test$y, Predicted = pred)
print(confusion_matrix)


#### TASK 2.6 - Optimal Tree & Logistic Regression ####

# Find probabilities of predicting y = 'yes' --> Compare with different thresholds and classify --> 
# --> Compute TPR & FPR for each threshold

# FIt a logistic regression model
fit_logistic <-  glm(y ~ ., data = train, family = "binomial")

# Predict probabilities on test data
# type = "response" will give predicted PROBABILITIES for y = 'yes'
prob_logistic <- predict(fit_logistic, newdata = test, type = "response") 
# type = "vector" will give predicted probabilities for each class, select y = 'yes' using [, "yes"]
prob_tree <- predict(optimalTree, newdata = test, type = "vector")[, "yes"]

# Define thresholds
thresholds <- seq(0.05, 0.95, by = 0.05)

# Initialize vectors to store TPR and FPR values for both models
tpr_tree <- numeric(length(thresholds)) # Array with equal amount of spots as number of thresholds
fpr_tree <- numeric(length(thresholds))
tpr_logistic <- numeric(length(thresholds))
fpr_logistic <- numeric(length(thresholds))

# Function to calculate TPR = True Positive Rate & FPR = False Positive Rates
compute_tpr_fpr <- function(probabilities, actuals, threshold) {
  predicted <- ifelse(probabilities > threshold, "yes", "no")
  
  # Confusion matrix
  confusion_matrix <- table(True = actuals, Predicted = predicted)
  print(confusion_matrix)
  
  TP <- confusion_matrix["yes", "yes"] # True Positive. 
  TN <- confusion_matrix["no", "no"] # True Negative.   
  FP <- confusion_matrix["no", "yes"] # False Positive  
  FN <- confusion_matrix["yes", "no"] # False Negative  
  
  # Compute TPR and FPR
  TPR <- TP / (TP + FN)  # True Positive Rate (Sensitivity = Recall)
  FPR <- FP / (FP + TN)  # False Positive Rate (1 - Specificity)
  
  return(c(TPR = TPR, FPR = FPR))
}

# Loop through each threshold and compute TPR and FPR for bOTh models
for (i in 1:length(thresholds)) {
  
  # For Decision Tree
  tpr_fpr_tree <- compute_tpr_fpr(prob_tree, test$y, thresholds[i])
  tpr_tree[i] <- tpr_fpr_tree[1]
  fpr_tree[i] <- tpr_fpr_tree[2]
  
  # For the Logistic Regression
  tpr_fpr_logistic <- compute_tpr_fpr(prob_logistic, test$y, thresholds[i])
  tpr_logistic[i] <- tpr_fpr_logistic[1]
  fpr_logistic[i] <- tpr_fpr_logistic[2]
    
}

# PLot ROC curve for both models
plot(fpr_tree, tpr_tree, type = "l", col = "red", lwd = 2, 
     xlab = "False Positive Rate", ylab = "True Positive Rate",
     main = "ROC Curve", xlim = c(0, 1), ylim = c(0, 1))
lines(fpr_logistic, tpr_logistic, col = "blue", lwd = 2)
# Add legend
legend("bottomright", legend = c("Decision Tree", "Logistic Regression"),
       col = c("red", "blue"), lwd = 2)

