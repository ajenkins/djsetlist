Prerequisites

- Ruby

```
cd djsetlist/
bundle install
# Manually edit input and output paths in graph_setlist.rb
ruby graph_setlist.rb

# If graphviz is not install
brew install graphviz
dot -Tpng output/path_to_file.dot > output/path_to_file.png
```
