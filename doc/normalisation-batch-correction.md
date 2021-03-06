Resistance Pre-processing
================
Dominic Pearce

``` r
library(affy)
library(tidyverse)
library(Biobase)
library(frma)
library(hgu133plus2frmavecs)
library(knitr)
library(sva)
library(reshape2)
library(testthat)
library(ggthemes)
library(cowplot); theme_set(theme_gray())
source("../../../functions/mostVar.R")
source("../../../functions/library/mdsArrange.R")
```

Here we'll read in our .cel files in batch, feature select and normalise using frma and loess normalisation
-----------------------------------------------------------------------------------------------------------

#### Create AffyBatch from .CEL files

``` r
dir_vec <- c("../data/Edinbrugh\ First\ Batch\ 170\ Samples", 
             "../data/Edinburgh Ori Fresh Frozen Sample/FF/")

affybatch_lst <- lapply(dir_vec, function(dir){
        setwd(dir)
        affybatch <- ReadAffy()
        setwd("../")
        affybatch
})
```

#### Feature selection

``` r
goodcalls_lst <- lapply(affybatch_lst, function(batch){
    #get present, marginal, absent calls
    ap <- mas5calls(batch)
    #for each gene check that it not called absent in less than 90% of samples
    goodcalls <- rowSums(exprs(ap) != "A") > (ncol(ap) / 10)
    row.names(ap)[which(goodcalls)]
})

#retreive common probes and write out
present_common <- do.call(intersect, goodcalls_lst)
```

``` r
data.frame(present_10 = c(length(goodcalls_lst[[1]]), 
                             length(goodcalls_lst[[2]]), 
                             length(present_common)),
            material = c("New", "Original", "Common")
            ) %>% knitr::kable()
```

|  present\_10| material |
|------------:|:---------|
|        38066| New      |
|        37581| Original |
|        31577| Common   |

#### 2-step normalisation - frma and loess

``` r
data(hgu133plus2frmavecs)
frma_lst <- lapply(affybatch_lst, function(batch){
  batch_frma <- frma(batch, input.vecs = hgu133plus2frmavecs)  
  batch_frma[present_common, ]
})

norm_lst <- lapply(frma_lst, function(batch){
                       mtx <- normalize.loess(exprs(batch))
                       exprs(batch) <- mtx
                       batch
})


resistset <- do.call(Biobase::combine, norm_lst)
resistset$batch <- grepl("Plus_2", colnames(resistset))
resistset$timepoint <- ifelse(grepl("PRE", colnames(resistset)), 
                              "pre", 
                              ifelse(grepl("POST", colnames(resistset)), 
                                     "post", 
                                     NA))
tmp1 <- gsub("\\_\\(HG-U133_Plus_2\\)", "", colnames(resistset))
tmp2 <- gsub("POST", "", tmp1)
tmp3 <- gsub("PRE", "", tmp2)
tmp4 <- gsub("3-", "", tmp3)
tmp5 <- gsub("\\.CEL", "", tmp4)
resistset$patient_id <- gsub(" ", "", tmp5)

#write_rds(resistset, "../output/resistset-sep-fselect-frma-loess.rds")
```

#### RAW

``` r
batchEffectDists <- function(mtx_input){
    #arrange
    resist_mlt <- melt(mtx_input)
    resist_mrg <- base::merge(resist_mlt, pData(resistset), by.x = "Var2", by.y = 0)
    resist_mrg$Var2 <- factor(resist_mrg$Var2, levels = unique(resist_mrg$Var2[order(resist_mrg$batch)]))
    #boxplot
    p_box <- ggplot(resist_mrg, aes(x = Var2, y = value, fill = batch)) + 
        geom_boxplot() +
        theme(legend.position = 'bottom',
            axis.ticks.x = element_blank(),
            axis.text.x = element_blank())
    #densityplot
    p_dist <- ggplot(resist_mrg, aes(x = value, colour = batch, group = Var2), alpha = 0.05) + 
        geom_line(stat = 'density', alpha = 0.2) + 
        theme_pander() +    
        theme(legend.position = 'none',
            axis.ticks.x = element_blank(),
            axis.text.x = element_blank()) 
    #plot
    p_box
    p_dist
}

batchEffectDists(exprs(resistset))
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-9-1.png" style="display: block; margin: auto;" />

``` r
batchEffectMDS <- function(mtx_input, colour_by){
    #arrange
    mv500 <- mostVar(mtx_input, 500) %>% row.names()
    arg500 <- mdsArrange(mtx_input[mv500,]) 
    mds_input <- base::merge(arg500, pData(resistset), by.x = 'ids', by.y = 0)
    #and plot
    ggplot(mds_input, aes_string("x", "y", colour = colour_by)) + 
        geom_point() + 
        theme_pander() + 
        theme(legend.position = 'bottom')
}

batchEffectMDS(exprs(resistset), "batch")
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-10-1.png" style="display: block; margin: auto;" />

``` r
batchEffectMDS(exprs(resistset), "timepoint")
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-10-2.png" style="display: block; margin: auto;" />

``` r
batchEffectMDS(exprs(resistset), "patient_id") + theme(legend.position = 'none')
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-10-3.png" style="display: block; margin: auto;" />

#### Post-ComBat

``` r
mtx_cb <- ComBat(exprs(resistset), batch = as.numeric(resistset$batch))
```

    ## Standardizing Data across genes

``` r
resistset_cb <- resistset
exprs(resistset_cb) <- mtx_cb
#write_rds(resistset_cb, "../output/resistset-sep-fselect-frma-loess-cb.rds")
```

``` r
batchEffectDists(exprs(resistset_cb))
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-12-1.png" style="display: block; margin: auto;" />

``` r
batchEffectMDS(exprs(resistset_cb), "batch")
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-12-2.png" style="display: block; margin: auto;" />

``` r
batchEffectMDS(exprs(resistset_cb), "timepoint")
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-12-3.png" style="display: block; margin: auto;" />

``` r
batchEffectMDS(exprs(resistset_cb)[, !is.na(resistset_cb$timepoint)], "patient_id") + theme(legend.position = 'none')
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-12-4.png" style="display: block; margin: auto;" />

``` r
raw_pre <- resistset[, which(resistset$timepoint == "pre")]
raw_post <- resistset[, which(resistset$timepoint == "post")]
cb_pre <- resistset_cb[, which(resistset_cb$timepoint == "pre")]
cb_post <- resistset_cb[, which(resistset_cb$timepoint == "post")]

test_that("matrices are in the same order", {
              expect_identical(raw_pre$patient_id, raw_post$patient_id)
            })

raw_pairs <- cor(exprs(raw_pre), exprs(raw_post)) %>% diag()
raw_all <- cor(exprs(resistset)) %>% rowMeans()
cb_pairs <- cor(exprs(cb_pre), exprs(cb_post)) %>% diag()
cb_all <- cor(exprs(resistset_cb)) %>% rowMeans()


cor_dfr <- data.frame(cor = c(cb_pairs,
                              cb_all,
                              raw_pairs,
                              raw_all),
           correction = rep(c(TRUE, "FALSE"), each = 306),
           class = rep(c("pairs", "all", "pairs", "all"), c(85, 221, 85, 221)))


ggplot(cor_dfr, aes(x = class, y = cor)) + geom_boxplot(outlier.size = 0) +
    geom_jitter(width = 0.3) + 
    facet_wrap(~correction, nrow = 1) +
    theme_pander()
```

<img src="normalisation-batch-correction_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-13-1.png" style="display: block; margin: auto;" />
