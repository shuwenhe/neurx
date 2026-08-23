# neurx-serve

Stable serving executable boundary. Network lifecycle belongs to `src/serving`;
token generation is accessed through `src/inference/api`.

The launcher validates serving capacity and timeout settings, then executes the
production server supplied by `NEURX_SERVE_BIN`. See
`configs/inference/serve.example`.
