# Production source boundaries

The intended dependency direction is:

```text
agent / serving / training
            |
            v
inference / models
            |
            v
runtime / compiler / distributed
            |
            v
core <--- backends
```

Lower layers must not import higher product layers. Public APIs should be
exposed through a domain facade rather than by importing another domain's
internal files.
