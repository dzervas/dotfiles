; extends

; Inject language into block scalars based on key names
; Values like `values: |` or `manifest: |` will be treated as YAML.
; From https://github.com/nvim-treesitter/nvim-treesitter/blob/master/queries/yaml/injections.scm
(block_mapping_pair
   key: (flow_node) @key
   (#any-of? @key "yaml" "manifest" "values")
   value: (block_node
            (block_scalar) @injection.content
            (#set! injection.language "yaml")
            (#set! injection.include-children)
            (#offset! @injection.content 0 1 0 0)))

(block_mapping_pair
   key: (flow_node) @key
   (#match? @key "\.hurl$")
   value: (block_node
            (block_scalar) @injection.content
            (#set! injection.language "hurl")
            (#set! injection.include-children)
            (#offset! @injection.content 0 1 0 0)))
