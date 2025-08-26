# Running instructions
```bash
# Enter this `generator/` directory from the repo root
cd generator

# install deps
bun install

# Symbolically link the api specs into the expected location
ln -s $HUME/dev/fern-config/fern/apis apis/

bun .
```
