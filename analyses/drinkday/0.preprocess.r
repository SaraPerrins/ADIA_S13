library(tidyverse)

dat <- read.csv('C:/Users/21983/OneDrive - ICF/ADIA/study 1/data/finalvar_w.csv')
#dat <- haven::read_sas('data/rtree_test1.sas7bdat')
colnames(dat)[colnames(dat)%in%c('childid','biryear_xrnd','ygender_xrnd')] <-
  c('id','yob', 'sex')


dat$race[dat$white==1]<-2
dat$race[dat$black==1]<-3
dat$race[dat$asian_nhpi==1]<-4
dat$race[dat$asian==1]<-5
dat$race[dat$othrace==1]<-6
dat$race[dat$hisp==1]<-1

head(dat)

### 1.- Cleaning, recoding
#any Exposure
dat <-
  dat %>%
  mutate(
    anyACE=case_when(
      commstr!=0 | ecstand!=0 | bneedin!=0 | mloveaf!=0 | mphysab!=0 |
        msubstu!=0 | mmental!=0 | discrim!=0 | loveaff!=0 | incarce!=0 |
        divorce!=0 | physabu!=0 | subsuse!=0 | mentill!=0  ~ 1,
      commstr==0  & ecstand==0  & bneedin==0  & mloveaf==0  & mphysab==0  &
        msubstu==0  & mmental==0  & discrim==0  & loveaff==0  & incarce==0  &
        divorce==0  & physabu==0  & subsuse==0  & mentill==0   ~ 0
    ))

table(dat$anyACE)

##factors
dat$race <- factor(dat$race)
#Ellen: for ordinal variables it is better to treat them as numeric


summary(dat)


#Age in 2018
dat$ageo <- 2018-dat$yob

summary(dat)

#table(dat$sex)
#dat$sex[dat$sex=='I'] <- NA
#dat$female <- as.numeric(dat$sex)-1

#drop cases with no traditional ACE info
dat <-
  dat %>%
  filter(!is.na(anyACE))
summary(dat)

### 2.- define a training sample------------------------------------------------

#simple random sample
#dat$ts  <- dat$id%in%sample(unique(dat$id), length(unique(dat$id))/2)

#stratfied random sample
#how to define strata? stratifed random sample from sex, race, gender, anyace
dat <-
  dat %>%
  mutate(strata=paste0(sex,
    race,cut(yob,3),anyACE)) %>%
  group_by(strata) %>%
  mutate(training.sample=if_else(id%in%sample(unique(id), round(n_distinct(id)/2)),1,0)) %>%
  ungroup



n_distinct(dat$strata)
table(dat$strata, dat$training.sample)
#ideally training sample is equal to valdation sample


saveRDS(dat,'C:/Users/21983/OneDrive - ICF/ADIA/study 1/data/finalvar.Rds')