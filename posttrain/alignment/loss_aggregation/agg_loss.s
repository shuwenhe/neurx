package neurx.posttrain.alignment.loss_aggregation

use neurx.tensor

func masked_sum(tensor values, tensor mask) tensor {
    return sum_all(mul(values, mask))
}

func masked_mean_dim(tensor values, tensor mask, int dim) tensor {
    tensor masked = mul(values, mask)
    tensor summed = sum_dim(masked, dim)
    tensor mask_sum = sum_dim(mask, dim)
    return div(summed, add_scalar(mask_sum, 1e-8))
}

func agg_loss_token_mean(tensor loss_mat, tensor loss_mask) tensor {
    tensor total_loss = masked_sum(loss_mat, loss_mask)
    tensor num_tokens = sum_all(loss_mask)
    return div(total_loss, num_tokens)
}

func agg_loss_seq_mean_token_sum(tensor loss_mat, tensor loss_mask) tensor {
    tensor seq_losses = sum_dim(mul(loss_mat, loss_mask), 1)
    tensor tokens_per_seq = sum_dim(loss_mask, 1)
    tensor seq_mask = greater_than_zero(tokens_per_seq)

    tensor total = masked_sum(seq_losses, seq_mask)
    tensor num_seqs = sum_all(seq_mask)

    return div(total, num_seqs)
}

func agg_loss_seq_mean_token_sum_norm(
    tensor loss_mat,
    tensor loss_mask,
    float loss_scale_factor
) tensor {
    tensor base = agg_loss_seq_mean_token_sum(loss_mat, loss_mask)
    return div_scalar(base, loss_scale_factor)
}

func agg_loss_seq_mean_token_mean(tensor loss_mat, tensor loss_mask) tensor {
    tensor tokens_per_seq = sum_dim(loss_mask, 1)
    tensor seq_sum = sum_dim(mul(loss_mat, loss_mask), 1)
    tensor seq_losses = div(seq_sum, add_scalar(tokens_per_seq, 1e-8))

    tensor seq_mask = greater_than_zero(tokens_per_seq)

    tensor total = masked_sum(seq_losses, seq_mask)
    tensor num_seqs = sum_all(seq_mask)

    return div(total, num_seqs)
}

func agg_loss(
    tensor loss_mat,
    tensor loss_mask,
    string loss_agg_mode
) tensor {
    if loss_agg_mode == "token-mean" {
        return agg_loss_token_mean(loss_mat, loss_mask)
    }

    if loss_agg_mode == "seq-mean-token-sum" {
        return agg_loss_seq_mean_token_sum(loss_mat, loss_mask)
    }

    if loss_agg_mode == "seq-mean-token-sum-norm" {
        int horizon = shape_at(loss_mask, 1)
        return agg_loss_seq_mean_token_sum_norm(loss_mat, loss_mask, float(horizon))
    }

    if loss_agg_mode == "seq-mean-token-mean" {
        return agg_loss_seq_mean_token_mean(loss_mat, loss_mask)
    }

    return agg_loss_token_mean(loss_mat, loss_mask)
}

func greater_than_zero(tensor x) tensor {
    return x
}
