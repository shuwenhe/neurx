package main
use neurx.stats
func assert_true(bool value, string name) {
    if value {
        println("PASS " + name)
    } else {
        println("FAIL " + name)
    }
}

func assert_close(float actual, float expected, string name) {
    float diff = actual - expected
    if diff < 0.0 {
        diff = -diff
    }
    assert_true(diff < 0.0001, name)
}

func test_sort_topk_cumsum() {
    tensor a = tensor {
        data: [3.0, 1.0, 4.0, 2.0],
        shape: [4],
        requires_grad: false,
        grad: none,
    }
    tensor sorted = neurx.stats.sort(a, 0)
    tensor top2 = neurx.stats.topk(a, 2)
    tensor csum = neurx.stats.cumsum(a, 0)
    tensor cprod = neurx.stats.cumprod(a, 0)
    tensor prod = neurx.stats.prod(a, 0)
    assert_close(sorted.data[0], 1.0, "sort 0")
    assert_close(sorted.data[1], 2.0, "sort 1")
    assert_close(sorted.data[2], 3.0, "sort 2")
    assert_close(sorted.data[3], 4.0, "sort 3")
    assert_close(top2.data[0], 4.0, "topk 0")
    assert_close(top2.data[1], 3.0, "topk 1")
    assert_close(csum.data[0], 3.0, "cumsum 0")
    assert_close(csum.data[1], 4.0, "cumsum 1")
    assert_close(csum.data[2], 8.0, "cumsum 2")
    assert_close(csum.data[3], 10.0, "cumsum 3")
    assert_close(cprod.data[0], 3.0, "cumprod 0")
    assert_close(cprod.data[1], 3.0, "cumprod 1")
    assert_close(cprod.data[2], 12.0, "cumprod 2")
    assert_close(cprod.data[3], 24.0, "cumprod 3")
    assert_close(prod.data[0], 24.0, "prod all")
}

func test_dim_reductions() {
    tensor b = tensor {
        data: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
        requires_grad: false,
        grad: none,
    }
    tensor csum_dim1 = neurx.stats.cumsum(b, 1)
    tensor cprod_dim1 = neurx.stats.cumprod(b, 1)
    tensor prod_dim1 = neurx.stats.prod_dim(b, 1)
    tensor prod_dim0 = neurx.stats.prod(b, 0)
    assert_close(csum_dim1.data[0], 1.0, "cumsum dim1 0")
    assert_close(csum_dim1.data[1], 3.0, "cumsum dim1 1")
    assert_close(csum_dim1.data[2], 6.0, "cumsum dim1 2")
    assert_close(csum_dim1.data[3], 4.0, "cumsum dim1 3")
    assert_close(csum_dim1.data[4], 9.0, "cumsum dim1 4")
    assert_close(csum_dim1.data[5], 15.0, "cumsum dim1 5")
    assert_close(cprod_dim1.data[0], 1.0, "cumprod dim1 0")
    assert_close(cprod_dim1.data[1], 2.0, "cumprod dim1 1")
    assert_close(cprod_dim1.data[2], 6.0, "cumprod dim1 2")
    assert_close(cprod_dim1.data[3], 4.0, "cumprod dim1 3")
    assert_close(cprod_dim1.data[4], 20.0, "cumprod dim1 4")
    assert_close(cprod_dim1.data[5], 120.0, "cumprod dim1 5")
    assert_close(prod_dim1.data[0], 6.0, "prod dim1 row0")
    assert_close(prod_dim1.data[1], 120.0, "prod dim1 row1")
    assert_close(prod_dim0.data[0], 4.0, "prod dim0 col0")
    assert_close(prod_dim0.data[1], 10.0, "prod dim0 col1")
    assert_close(prod_dim0.data[2], 18.0, "prod dim0 col2")
}

func test_sort_argsort_topk_dim() {
    tensor a = tensor {
        data: [4.0, 1.0, 6.0, 3.0, 5.0, 2.0],
        shape: [2, 3],
        requires_grad: false,
        grad: none,
    }
    tensor sorted_rows = neurx.stats.sort(a, 1)
    tensor sorted_cols = neurx.stats.sort(a, 0)
    tensor argsorted_rows = neurx.stats.argsort(a, 1)
    tensor top2_rows = neurx.stats.topk_dim(a, 2, 1)
    tensor top2_cols = neurx.stats.topk_dim(a, 2, 0)
    assert_close(sorted_rows.data[0], 1.0, "sort row0 0")
    assert_close(sorted_rows.data[1], 4.0, "sort row0 1")
    assert_close(sorted_rows.data[2], 6.0, "sort row0 2")
    assert_close(sorted_rows.data[3], 2.0, "sort row1 0")
    assert_close(sorted_rows.data[4], 3.0, "sort row1 1")
    assert_close(sorted_rows.data[5], 5.0, "sort row1 2")
    assert_close(sorted_cols.data[0], 3.0, "sort col0 0")
    assert_close(sorted_cols.data[1], 1.0, "sort col0 1")
    assert_close(sorted_cols.data[2], 2.0, "sort col0 2")
    assert_close(sorted_cols.data[3], 4.0, "sort col1 0")
    assert_close(sorted_cols.data[4], 5.0, "sort col1 1")
    assert_close(sorted_cols.data[5], 6.0, "sort col1 2")
    assert_close(argsorted_rows.data[0], 1.0, "argsort row0 0")
    assert_close(argsorted_rows.data[1], 0.0, "argsort row0 1")
    assert_close(argsorted_rows.data[2], 2.0, "argsort row0 2")
    assert_close(argsorted_rows.data[3], 2.0, "argsort row1 0")
    assert_close(argsorted_rows.data[4], 0.0, "argsort row1 1")
    assert_close(argsorted_rows.data[5], 1.0, "argsort row1 2")
    assert_close(top2_rows.data[0], 6.0, "topk dim row0 0")
    assert_close(top2_rows.data[1], 4.0, "topk dim row0 1")
    assert_close(top2_rows.data[2], 5.0, "topk dim row1 0")
    assert_close(top2_rows.data[3], 3.0, "topk dim row1 1")
    assert_close(top2_cols.data[0], 4.0, "topk dim col0 0")
    assert_close(top2_cols.data[1], 1.0, "topk dim col0 1")
    assert_close(top2_cols.data[2], 6.0, "topk dim col1 0")
    assert_close(top2_cols.data[3], 3.0, "topk dim col1 1")
    assert_close(top2_cols.data[4], 5.0, "topk dim col2 0")
    assert_close(top2_cols.data[5], 2.0, "topk dim col2 1")
}

func test_scalar_stats() {
    tensor a = tensor {
        data: [2.0, 4.0, 4.0, 8.0, 1.0],
        shape: [5],
        requires_grad: false,
        grad: none,
    }
    tensor unique_vals = neurx.stats.unique(a)
    tensor median_val = neurx.stats.median(a)
    tensor mode_val = neurx.stats.mode(a)
    tensor quantile_val = neurx.stats.quantile(a, 0.5)
    assert_close(unique_vals.data[0], 2.0, "unique 0")
    assert_close(unique_vals.data[1], 4.0, "unique 1")
    assert_close(unique_vals.data[2], 8.0, "unique 2")
    assert_close(unique_vals.data[3], 1.0, "unique 3")
    assert_close(median_val.data[0], 4.0, "median")
    assert_close(mode_val.data[0], 4.0, "mode")
    assert_close(quantile_val.data[0], 4.0, "quantile")
    tensor sum_val = neurx.stats.sum(a)
    tensor mean_val = neurx.stats.mean(a)
    tensor max_val = neurx.stats.max(a)
    tensor min_val = neurx.stats.min(a)
    tensor argmax_val = neurx.stats.argmax(a)
    tensor argmin_val = neurx.stats.argmin(a)
    assert_close(sum_val.data[0], 19.0, "sum")
    assert_close(mean_val.data[0], 3.8, "mean")
    assert_close(max_val.data[0], 8.0, "max")
    assert_close(min_val.data[0], 1.0, "min")
    assert_close(argmax_val.data[0], 3.0, "argmax")
    assert_close(argmin_val.data[0], 4.0, "argmin")
}

func test_dim_stats() {
    tensor a = tensor {
        data: [5.0, 1.0, 1.0, 9.0, 2.0, 2.0, 7.0, 8.0],
        shape: [2, 4],
        requires_grad: false,
        grad: none,
    }
    tensor median_rows = neurx.stats.median_dim(a, 1)
    tensor mode_rows = neurx.stats.mode_dim(a, 1)
    tensor quantile_rows = neurx.stats.quantile_dim(a, 0.75, 1)
    tensor sum_rows = neurx.stats.sum_dim(a, 1)
    tensor mean_rows2 = neurx.stats.mean_dim(a, 1)
    tensor max_rows = neurx.stats.max_dim(a, 1)
    tensor min_rows = neurx.stats.min_dim(a, 1)
    tensor argmax_rows = neurx.stats.argmax_dim(a, 1)
    tensor argmin_rows = neurx.stats.argmin_dim(a, 1)
    assert_close(median_rows.data[0], 3.0, "median dim row0")
    assert_close(median_rows.data[1], 4.5, "median dim row1")
    assert_close(mode_rows.data[0], 1.0, "mode dim row0")
    assert_close(mode_rows.data[1], 2.0, "mode dim row1")
    assert_close(quantile_rows.data[0], 5.0, "quantile dim row0")
    assert_close(quantile_rows.data[1], 7.0, "quantile dim row1")
    assert_close(sum_rows.data[0], 16.0, "sum dim row0")
    assert_close(sum_rows.data[1], 19.0, "sum dim row1")
    assert_close(mean_rows2.data[0], 4.0, "mean dim row0")
    assert_close(mean_rows2.data[1], 4.75, "mean dim row1")
    assert_close(max_rows.data[0], 9.0, "max dim row0")
    assert_close(max_rows.data[1], 8.0, "max dim row1")
    assert_close(min_rows.data[0], 1.0, "min dim row0")
    assert_close(min_rows.data[1], 2.0, "min dim row1")
    assert_close(argmax_rows.data[0], 3.0, "argmax dim row0")
    assert_close(argmax_rows.data[1], 3.0, "argmax dim row1")
    assert_close(argmin_rows.data[0], 1.0, "argmin dim row0")
    assert_close(argmin_rows.data[1], 0.0, "argmin dim row1")
    tensor uniq_rows = neurx.stats.unique_dim(a, 1)
    assert_close(uniq_rows.data[0], 5.0, "unique dim row0 0")
    assert_close(uniq_rows.data[1], 1.0, "unique dim row0 1")
    assert_close(uniq_rows.data[2], 0.0, "unique dim row0 2")
    assert_close(uniq_rows.data[3], 0.0, "unique dim row0 3")
    assert_close(uniq_rows.data[4], 2.0, "unique dim row1 0")
    assert_close(uniq_rows.data[5], 7.0, "unique dim row1 1")
    assert_close(uniq_rows.data[6], 8.0, "unique dim row1 2")
    assert_close(uniq_rows.data[7], 0.0, "unique dim row1 3")
    tensor b = tensor {
        data: [1.0, 2.0, 2.0, 3.0, 1.0, 5.0, 2.0, 4.0],
        shape: [2, 4],
        requires_grad: false,
        grad: none,
    }
    tensor uniq_cols = neurx.stats.unique_dim(b, 0)
    assert_close(uniq_cols.data[0], 1.0, "unique dim col0 0")
    assert_close(uniq_cols.data[1], 2.0, "unique dim col0 1")
    assert_close(uniq_cols.data[2], 2.0, "unique dim col0 2")
    assert_close(uniq_cols.data[3], 3.0, "unique dim col0 3")
    assert_close(uniq_cols.data[4], 0.0, "unique dim col1 0")
    assert_close(uniq_cols.data[5], 5.0, "unique dim col1 1")
    assert_close(uniq_cols.data[6], 0.0, "unique dim col1 2")
    assert_close(uniq_cols.data[7], 4.0, "unique dim col1 3")
    tensor c = tensor {
        data: [1.0, 3.0, 5.0, 7.0, 2.0, 4.0, 6.0, 8.0],
        shape: [2, 4],
        requires_grad: false,
        grad: none,
    }
    tensor median_cols = neurx.stats.median_dim(c, 0)
    tensor mode_cols = neurx.stats.mode_dim(c, 0)
    tensor quantile_cols = neurx.stats.quantile_dim(c, 0.25, 0)
    assert_close(median_cols.data[0], 1.5, "median dim col0")
    assert_close(median_cols.data[1], 3.5, "median dim col1")
    assert_close(median_cols.data[2], 5.5, "median dim col2")
    assert_close(median_cols.data[3], 7.5, "median dim col3")
    assert_close(mode_cols.data[0], 1.0, "mode dim col0")
    assert_close(mode_cols.data[1], 3.0, "mode dim col1")
    assert_close(mode_cols.data[2], 5.0, "mode dim col2")
    assert_close(mode_cols.data[3], 7.0, "mode dim col3")
    assert_close(quantile_cols.data[0], 1.0, "quantile dim col0")
    assert_close(quantile_cols.data[1], 3.0, "quantile dim col1")
    assert_close(quantile_cols.data[2], 5.0, "quantile dim col2")
    assert_close(quantile_cols.data[3], 7.0, "quantile dim col3")
    tensor sum_cols = neurx.stats.sum_dim(c, 0)
    assert_close(sum_cols.data[0], 3.0, "sum dim col0")
    assert_close(sum_cols.data[1], 7.0, "sum dim col1")
    assert_close(sum_cols.data[2], 11.0, "sum dim col2")
    assert_close(sum_cols.data[3], 15.0, "sum dim col3")
}

func main() {
    println("NeurX stats tests")
    test_sort_topk_cumsum()
    test_dim_reductions()
    test_sort_argsort_topk_dim()
    test_scalar_stats()
    test_dim_stats()
}
