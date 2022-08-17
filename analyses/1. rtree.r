library(tidyverse)
library(rpart)
library(partykit)
set.seed(0203)

dat <- readRDS('data/test.Rds')

### 0.- variables & roles
# expousures
x <- c('ACEmentalill','ACEalcohol','ACEphysharm','ACEaffection','ACEfoodins')
# covariates/confounding
z <- c('race','female','ageo')
dat$Z <- dat[,z]
dat$X <- dat[,x]
dat$y <- dat$gad7

df0 <-
  dat %>%
  filter(training.sample==1)



#===============================================================================
### 1.- 'Classical' regression tree (expousure & covariates are all lump together as predictors)
#===============================================================================
# the default action deletes all observations for which y is missing, but
# keeps those in which one or more predictors are missing.


#a.- grow large tree
tree <- with(df0, rpart(y ~ . , data=cbind(y,X,Z,anyACE),cp=-1,xval = 10, weights=w))
plotcp(tree,col='red' )
#A good choice of cp for pruning is often the leftmost value for which the mean lies below the horizontal line.

#b.- prune based on complexity
opcp <- tree$cptable[,'CP'][which.min(tree$cptable[,'xerror'])]
ptree <- prune(tree, cp = opcp)
#rpart.plot(optree)
plot(as.party(ptree))

png('output/tree.plot.unconditional.png',width = 480*4,heigh=480*4,res=300)
plot(as.party(ptree))
dev.off()



#===============================================================================
### 2.- Regression tree 'conditional' on covariates
#===============================================================================
# expousures and covaraites are treated differently
# we explore expousures after adjusting for covariates
#Reference:  Stanfill et al. (2019) https://doi.org/10.1177/1179597219858954

dat$W <-
  dat %>%
  mutate(strata=paste0(female,race,cut(yob,3))) %>%
  group_by(strata) %>%
  summarize(across(c(all_of(x),anyACE),~.x-weighted.mean(.x,w,na.rm=T))) %>%
  ungroup %>%
  select(-1)

df0 <-
  dat %>%
  filter(training.sample==1)


#a.- grow large tree
tree <- with(df0, rpart(y ~ . , data=cbind(y,W),cp=-1, weights=w))
plotcp(tree,col='red' )
#A good choice of cp for pruning is often the leftmost value for which the mean lies below the horizontal line.

#b.- prune based on complexity
opcp <- tree$cptable[,'CP'][which.min(tree$cptable[,'xerror'])]
ptree.cond <- prune(tree, cp = opcp)
#rpart.plot(optree)
plot(as.party(ptree.cond))


png('output/tree.plot.conditional.png',width = 480*4,heigh=480*4,res=300)
plot(as.party(ptree.cond))
dev.off()

#===============================================================================
### 3.- A casual tree
#===============================================================================
# A particular exposure (any traditional ACEs) has a special role
# Its eefct is estiamted adjustong bu covariates
# the regression tree is used to explore whter the effect is modified by other expousures

### a. Find balancing weights among those with and without any ACEs
#Entropy Balancing
#Reference: #https://web.stanford.edu/~jhain/Paper/eb.pdf
source('R/ebw.r')

# In orther to balance the missing pattern we need to
# for categorical variables, create an NA category (addNA)
# this should inlcude binary varaibles not declared as s
# for continuous, add indicator is.na and impute mean

dat$C <-
  dat$Z %>%
  mutate(across(where(is.factor),addNA,ifany=T))  %>%
  mutate(across(where(~ is.numeric(.x) && any(is.na(.x)) && n_distinct(.x)==2), ~addNA(factor(.x)))) %>%
  mutate(across(where(~ is.numeric(.x) && any(is.na(.x))), is.na,.names = 'NA_{.col}')) %>%
  mutate(across(where(is.numeric),~ replace(.,is.na(.),mean(.,na.rm=T))))  %>%
  model.matrix(~.,.) %>%
  .[,-1]

summary(dat)


tgt  <- colMeans(dat$C); tgt
ebw1 <- with(dat, ebw(id=id[anyACE==1], covariates=C[anyACE==1,], target.margins=tgt, base.weight = w[anyACE==1]))
ebw0 <- with(dat, ebw(id=id[anyACE==0], covariates=C[anyACE==0,], target.margins=tgt, base.weight = w[anyACE==0]))
dat  <- left_join(dat,rbind(ebw0,ebw1))


with(dat,data.frame(C,anyACE,w,wb)) %>%
  group_by(anyACE) %>%
  summarize(across(everything(), list(
  ~ weighted.mean(.,w),
  ~ weighted.mean(.,wb))
  ))
df0 <-
  dat %>%
  filter(training.sample==1)

### b. find effect modofiers
#library(devtools)
#install_github("susanathey/causalTree")
#Reference https://doi.org/10.48550/arXiv.1504.01132
library(causalTree)
tree <- with(df0, causalTree(y~ ., data = cbind(y,X,Z,wb), treatment = anyACE, weights=wb,
                   split.Rule = "CT", cv.option = "CT", split.Honest = T, cv.Honest = T, split.Bucket = F,
                   xval = 5, cp = 0, minsize = 20, propensity = 0.5))

opcp <- tree$cptable[,1][which.min(tree$cptable[,4])]
ptree.causal <- prune(tree, opcp)

rpart.plot(ptree.causal)
plot(as.party(ptree.causal))


png('output/tree.plot.causal.png',width = 480*4,heigh=480*4,res=300)
rpart.plot(tree.causal)
dev.off()

#===============================================================================
### 4. Save class membership for all cases
#===============================================================================

dat$node.cls  <- factor(predict(as.party(ptree),type='node',newdata=dat))
dat$node.cnd  <- factor(predict(as.party(ptree.cond),type='node',newdata=dat))
dat$node.cau  <- factor(predict(as.party(ptree.causal),type='node',newdata=dat))



saveRDS(dat,'data/test.tree.Rds')