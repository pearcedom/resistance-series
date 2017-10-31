# Top n variable genes
# Data is an expression matrix (samples in columns, genes in rows)
# n is the number of genes you want to subset by
# i_want_most_var can be changed to FALSE to get the least variable genes instead

mostVar <- function(data, n, i_want_most_var = TRUE) {
  data.var <- apply(data, 1, var)
  
  data[order(data.var, decreasing = i_want_most_var)[1:n],] 
}
