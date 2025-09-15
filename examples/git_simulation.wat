(module
  ;; Memory for Git object storage simulation
  (memory (export "memory") 512)

  ;; Git object types
  (global $OBJ_COMMIT i32 (i32.const 1))
  (global $OBJ_TREE i32 (i32.const 2))
  (global $OBJ_BLOB i32 (i32.const 3))
  (global $OBJ_TAG i32 (i32.const 4))

  ;; Memory layout:
  ;; 0x0000-0x3FFF: Object storage area
  ;; 0x4000-0x7FFF: Index/cache area
  ;; 0x8000-0xBFFF: Working directory simulation
  ;; 0xC000-0xFFFF: Temporary calculation space

  ;; Git-style SHA-1 hash calculation (simplified)
  (func $git_hash_object (export "git_hash_object") (param $obj_type i32) (param $size i32) (param $offset i32) (result i32)
    (local $h0 i32) (local $h1 i32) (local $h2 i32) (local $h3 i32) (local $h4 i32)
    (local $w i32) (local $temp i32) (local $i i32) (local $f i32) (local $k i32)
    (local $a i32) (local $b i32) (local $c i32) (local $d i32) (local $e i32)

    ;; SHA-1 initial hash values
    (local.set $h0 (i32.const 0x67452301))
    (local.set $h1 (i32.const 0xEFCDAB89))
    (local.set $h2 (i32.const 0x98BADCFE))
    (local.set $h3 (i32.const 0x10325476))
    (local.set $h4 (i32.const 0xC3D2E1F0))

    ;; Initialize working variables
    (local.set $a (local.get $h0))
    (local.set $b (local.get $h1))
    (local.set $c (local.get $h2))
    (local.set $d (local.get $h3))
    (local.set $e (local.get $h4))

    ;; Main SHA-1 loop (simplified for 80 rounds)
    (local.set $i (i32.const 0))
    (loop $sha1_loop
      ;; Generate message schedule W[i]
      (if (i32.lt_u (local.get $i) (i32.const 16))
        (then
          ;; Use object data with type header
          (local.set $w (i32.add
            (i32.load (i32.add (local.get $offset) (i32.mul (local.get $i) (i32.const 4))))
            (i32.mul (local.get $obj_type) (i32.const 0x12345678))
          ))
        )
        (else
          ;; W[i] = ROTL(W[i-3] XOR W[i-8] XOR W[i-14] XOR W[i-16], 1)
          (local.set $w (i32.rotl
            (i32.xor
              (i32.xor
                (i32.load (i32.add (i32.const 0xC000) (i32.mul (i32.sub (local.get $i) (i32.const 3)) (i32.const 4))))
                (i32.load (i32.add (i32.const 0xC000) (i32.mul (i32.sub (local.get $i) (i32.const 8)) (i32.const 4))))
              )
              (i32.xor
                (i32.load (i32.add (i32.const 0xC000) (i32.mul (i32.sub (local.get $i) (i32.const 14)) (i32.const 4))))
                (i32.load (i32.add (i32.const 0xC000) (i32.mul (i32.sub (local.get $i) (i32.const 16)) (i32.const 4))))
              )
            )
            (i32.const 1)
          ))
        )
      )

      ;; Store W[i] for future rounds
      (i32.store (i32.add (i32.const 0xC000) (i32.mul (local.get $i) (i32.const 4))) (local.get $w))

      ;; Calculate f and k based on round
      (if (i32.lt_u (local.get $i) (i32.const 20))
        (then
          (local.set $f (i32.or
            (i32.and (local.get $b) (local.get $c))
            (i32.and (i32.xor (local.get $b) (i32.const 0xffffffff)) (local.get $d))
          ))
          (local.set $k (i32.const 0x5A827999))
        )
        (else
          (if (i32.lt_u (local.get $i) (i32.const 40))
            (then
              (local.set $f (i32.xor (i32.xor (local.get $b) (local.get $c)) (local.get $d)))
              (local.set $k (i32.const 0x6ED9EBA1))
            )
            (else
              (if (i32.lt_u (local.get $i) (i32.const 60))
                (then
                  (local.set $f (i32.or
                    (i32.or
                      (i32.and (local.get $b) (local.get $c))
                      (i32.and (local.get $b) (local.get $d))
                    )
                    (i32.and (local.get $c) (local.get $d))
                  ))
                  (local.set $k (i32.const 0x8F1BBCDC))
                )
                (else
                  (local.set $f (i32.xor (i32.xor (local.get $b) (local.get $c)) (local.get $d)))
                  (local.set $k (i32.const 0xCA62C1D6))
                )
              )
            )
          )
        )
      )

      ;; temp = ROTL(a,5) + f + e + k + w
      (local.set $temp (i32.add
        (i32.add
          (i32.add
            (i32.add (i32.rotl (local.get $a) (i32.const 5)) (local.get $f))
            (local.get $e)
          )
          (local.get $k)
        )
        (local.get $w)
      ))

      ;; Update working variables
      (local.set $e (local.get $d))
      (local.set $d (local.get $c))
      (local.set $c (i32.rotl (local.get $b) (i32.const 30)))
      (local.set $b (local.get $a))
      (local.set $a (local.get $temp))

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $sha1_loop (i32.lt_u (local.get $i) (i32.const 80)))
    )

    ;; Add this chunk's hash to result
    (local.set $h0 (i32.add (local.get $h0) (local.get $a)))
    (local.set $h1 (i32.add (local.get $h1) (local.get $b)))
    (local.set $h2 (i32.add (local.get $h2) (local.get $c)))
    (local.set $h3 (i32.add (local.get $h3) (local.get $d)))
    (local.set $h4 (i32.add (local.get $h4) (local.get $e)))

    ;; Return combined hash (simplified to 32-bit)
    (i32.xor
      (i32.xor (local.get $h0) (local.get $h1))
      (i32.xor (i32.xor (local.get $h2) (local.get $h3)) (local.get $h4))
    )
  )

  ;; Git pack file compression simulation (delta compression)
  (func $delta_compression (export "delta_compression") (param $base_offset i32) (param $target_offset i32) (param $size i32) (result i32)
    (local $i i32) (local $j i32) (local $best_match_len i32) (local $best_match_offset i32)
    (local $current_match_len i32) (local $compression_ratio i32) (local $delta_size i32)
    (local $base_byte i32) (local $target_byte i32) (local $match_start i32)

    ;; Sliding window delta compression algorithm
    (loop $compress_loop
      (local.set $best_match_len (i32.const 0))
      (local.set $best_match_offset (i32.const 0))

      ;; Look for matches in a sliding window
      (local.set $j (i32.const 0))
      (loop $search_loop
        (if (i32.lt_u (local.get $j) (local.get $i))
          (then
            (local.set $current_match_len (i32.const 0))
            (local.set $match_start (local.get $j))

            ;; Count matching bytes
            (loop $match_loop
              (local.set $base_byte (i32.load8_u (i32.add (local.get $base_offset) (local.get $match_start))))
              (local.set $target_byte (i32.load8_u (i32.add (local.get $target_offset) (local.get $i))))

              (if (i32.eq (local.get $base_byte) (local.get $target_byte))
                (then
                  (local.set $current_match_len (i32.add (local.get $current_match_len) (i32.const 1)))
                  (local.set $match_start (i32.add (local.get $match_start) (i32.const 1)))
                  (if (i32.and
                    (i32.lt_u (local.get $match_start) (local.get $size))
                    (i32.lt_u (i32.add (local.get $i) (local.get $current_match_len)) (local.get $size))
                  )
                    (then (br $match_loop))
                  )
                )
              )
            )

            ;; Update best match if this one is better
            (if (i32.gt_u (local.get $current_match_len) (local.get $best_match_len))
              (then
                (local.set $best_match_len (local.get $current_match_len))
                (local.set $best_match_offset (local.get $j))
              )
            )
          )
        )

        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $search_loop (i32.lt_u (local.get $j) (i32.sub (local.get $i) (i32.const 1))))
      )

      ;; Encode the match or literal
      (if (i32.gt_u (local.get $best_match_len) (i32.const 3))
        (then
          ;; Encode as copy instruction (offset, length)
          (i32.store8 (i32.add (i32.const 0x8000) (local.get $delta_size)) (i32.const 0x80)) ;; Copy flag
          (local.set $delta_size (i32.add (local.get $delta_size) (i32.const 1)))
          (i32.store (i32.add (i32.const 0x8000) (local.get $delta_size)) (local.get $best_match_offset))
          (local.set $delta_size (i32.add (local.get $delta_size) (i32.const 4)))
          (i32.store (i32.add (i32.const 0x8000) (local.get $delta_size)) (local.get $best_match_len))
          (local.set $delta_size (i32.add (local.get $delta_size) (i32.const 4)))
          (local.set $i (i32.add (local.get $i) (local.get $best_match_len)))
        )
        (else
          ;; Encode as literal
          (i32.store8 (i32.add (i32.const 0x8000) (local.get $delta_size))
            (i32.load8_u (i32.add (local.get $target_offset) (local.get $i)))
          )
          (local.set $delta_size (i32.add (local.get $delta_size) (i32.const 1)))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
        )
      )

      (br_if $compress_loop (i32.lt_u (local.get $i) (local.get $size)))
    )

    ;; Calculate compression ratio
    (local.set $compression_ratio (i32.div_u
      (i32.mul (local.get $delta_size) (i32.const 100))
      (local.get $size)
    ))

    (local.get $compression_ratio)
  )

  ;; Git index operations simulation
  (func $git_index_operations (export "git_index_operations") (param $num_files i32) (result i32)
    (local $i i32) (local $file_hash i32) (local $index_entry i32)
    (local $stage_flags i32) (local $mode i32) (local $size i32)
    (local $total_hash i32) (local $conflicts i32)

    ;; Simulate index operations for multiple files
    (loop $index_loop
      ;; Generate file metadata
      (local.set $mode (i32.add (i32.const 33188) (i32.rem_u (local.get $i) (i32.const 4))))
      (local.set $size (i32.mul (local.get $i) (i32.const 1024)))
      (local.set $stage_flags (i32.rem_u (local.get $i) (i32.const 4)))

      ;; Create file content and hash it
      (i32.store (i32.add (i32.const 0x8000) (i32.mul (local.get $i) (i32.const 64)))
        (i32.add (local.get $i) (i32.const 0xDEADBEEF))
      )

      (local.set $file_hash (call $git_hash_object
        (global.get $OBJ_BLOB)
        (local.get $size)
        (i32.add (i32.const 0x8000) (i32.mul (local.get $i) (i32.const 64)))
      ))

      ;; Store index entry
      (local.set $index_entry (i32.add (i32.const 0x4000) (i32.mul (local.get $i) (i32.const 32))))
      (i32.store (local.get $index_entry) (local.get $file_hash))
      (i32.store (i32.add (local.get $index_entry) (i32.const 4)) (local.get $mode))
      (i32.store (i32.add (local.get $index_entry) (i32.const 8)) (local.get $size))
      (i32.store (i32.add (local.get $index_entry) (i32.const 12)) (local.get $stage_flags))

      ;; Simulate merge conflicts
      (if (i32.eq (local.get $stage_flags) (i32.const 3))
        (then (local.set $conflicts (i32.add (local.get $conflicts) (i32.const 1))))
      )

      ;; Update total hash
      (local.set $total_hash (i32.xor (local.get $total_hash) (local.get $file_hash)))

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $index_loop (i32.lt_u (local.get $i) (local.get $num_files)))
    )

    ;; Perform index sorting simulation
    (call $quicksort_index (i32.const 0x4000) (local.get $num_files))

    (i32.add (local.get $total_hash) (local.get $conflicts))
  )

  ;; Quicksort for index entries (simplified)
  (func $quicksort_index (param $base i32) (param $count i32)
    (local $i i32) (local $j i32) (local $pivot i32) (local $temp i32)
    (local $left i32) (local $right i32)

    (if (i32.gt_u (local.get $count) (i32.const 1))
      (then
        (local.set $pivot (i32.load (local.get $base)))
        (local.set $left (i32.const 0))
        (local.set $right (i32.sub (local.get $count) (i32.const 1)))

        (loop $partition_loop
          ;; Find element greater than pivot from left
          (loop $left_scan
            (if (i32.and
              (i32.lt_u (local.get $left) (local.get $right))
              (i32.le_u (i32.load (i32.add (local.get $base) (i32.mul (local.get $left) (i32.const 32)))) (local.get $pivot))
            )
              (then
                (local.set $left (i32.add (local.get $left) (i32.const 1)))
                (br $left_scan)
              )
            )
          )

          ;; Find element less than pivot from right
          (loop $right_scan
            (if (i32.and
              (i32.gt_u (local.get $right) (local.get $left))
              (i32.gt_u (i32.load (i32.add (local.get $base) (i32.mul (local.get $right) (i32.const 32)))) (local.get $pivot))
            )
              (then
                (local.set $right (i32.sub (local.get $right) (i32.const 1)))
                (br $right_scan)
              )
            )
          )

          (if (i32.lt_u (local.get $left) (local.get $right))
            (then
              ;; Swap elements
              (local.set $temp (i32.load (i32.add (local.get $base) (i32.mul (local.get $left) (i32.const 32)))))
              (i32.store
                (i32.add (local.get $base) (i32.mul (local.get $left) (i32.const 32)))
                (i32.load (i32.add (local.get $base) (i32.mul (local.get $right) (i32.const 32))))
              )
              (i32.store (i32.add (local.get $base) (i32.mul (local.get $right) (i32.const 32))) (local.get $temp))
              (local.set $left (i32.add (local.get $left) (i32.const 1)))
              (local.set $right (i32.sub (local.get $right) (i32.const 1)))
              (br $partition_loop)
            )
          )
        )

        ;; Recursively sort partitions
        (call $quicksort_index (local.get $base) (local.get $right))
        (call $quicksort_index
          (i32.add (local.get $base) (i32.mul (i32.add (local.get $right) (i32.const 1)) (i32.const 32)))
          (i32.sub (local.get $count) (i32.add (local.get $right) (i32.const 1)))
        )
      )
    )
  )

  ;; Git tree traversal simulation
  (func $tree_traversal (export "tree_traversal") (param $tree_depth i32) (param $files_per_dir i32) (result i32)
    (local $total_objects i32) (local $current_depth i32) (local $i i32)
    (local $tree_hash i32) (local $subtree_hash i32) (local $file_hash i32)

    (local.set $current_depth (i32.const 0))
    (loop $depth_loop
      (local.set $i (i32.const 0))
      (loop $files_loop
        ;; Create file objects
        (local.set $file_hash (call $git_hash_object
          (global.get $OBJ_BLOB)
          (i32.mul (local.get $i) (i32.const 256))
          (i32.add (i32.const 0x1000) (i32.mul (local.get $i) (i32.const 64)))
        ))
        (local.set $total_objects (i32.add (local.get $total_objects) (i32.const 1)))

        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br_if $files_loop (i32.lt_u (local.get $i) (local.get $files_per_dir)))
      )

      ;; Create tree object for this directory
      (local.set $tree_hash (call $git_hash_object
        (global.get $OBJ_TREE)
        (i32.mul (local.get $files_per_dir) (i32.const 32))
        (i32.const 0x2000)
      ))
      (local.set $total_objects (i32.add (local.get $total_objects) (i32.const 1)))

      ;; Create subtrees if not at max depth
      (if (i32.lt_u (local.get $current_depth) (i32.sub (local.get $tree_depth) (i32.const 1)))
        (then
          (local.set $subtree_hash (call $tree_traversal
            (i32.sub (local.get $tree_depth) (local.get $current_depth))
            (local.get $files_per_dir)
          ))
          (local.set $total_objects (i32.add (local.get $total_objects) (local.get $subtree_hash)))
        )
      )

      (local.set $current_depth (i32.add (local.get $current_depth) (i32.const 1)))
      (br_if $depth_loop (i32.lt_u (local.get $current_depth) (local.get $tree_depth)))
    )

    (local.get $total_objects)
  )

  ;; Git commit simulation
  (func $git_commit_chain (export "git_commit_chain") (param $num_commits i32) (result i32)
    (local $i i32) (local $parent_hash i32) (local $commit_hash i32)
    (local $tree_hash i32) (local $total_hash i32) (local $commit_size i32)

    (loop $commit_loop
      ;; Create tree for this commit
      (local.set $tree_hash (call $tree_traversal (i32.const 3) (i32.const 10)))

      ;; Build commit object (simplified)
      (local.set $commit_size (i32.const 256))
      (i32.store (i32.const 0x3000) (local.get $tree_hash))
      (i32.store (i32.const 0x3004) (local.get $parent_hash))
      (i32.store (i32.const 0x3008) (i32.add (local.get $i) (i32.const 0x12345678))) ;; Author timestamp
      (i32.store (i32.const 0x300C) (i32.add (local.get $i) (i32.const 0x87654321))) ;; Committer timestamp

      ;; Hash the commit
      (local.set $commit_hash (call $git_hash_object
        (global.get $OBJ_COMMIT)
        (local.get $commit_size)
        (i32.const 0x3000)
      ))

      ;; Update chain
      (local.set $parent_hash (local.get $commit_hash))
      (local.set $total_hash (i32.xor (local.get $total_hash) (local.get $commit_hash)))

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $commit_loop (i32.lt_u (local.get $i) (local.get $num_commits)))
    )

    (local.get $total_hash)
  )

  ;; Complete Git simulation benchmark
  (func $git_simulation_benchmark (export "git_simulation_benchmark") (param $scale i32) (result i32)
    (local $result i32) (local $temp i32)

    ;; Simulate repository operations
    (local.set $temp (call $git_commit_chain (i32.mul (local.get $scale) (i32.const 100))))
    (local.set $result (i32.add (local.get $result) (local.get $temp)))

    ;; Simulate index operations
    (local.set $temp (call $git_index_operations (i32.mul (local.get $scale) (i32.const 1000))))
    (local.set $result (i32.xor (local.get $result) (local.get $temp)))

    ;; Simulate delta compression
    (local.set $temp (call $delta_compression
      (i32.const 0x1000)
      (i32.const 0x2000)
      (i32.mul (local.get $scale) (i32.const 4096))
    ))
    (local.set $result (i32.add (local.get $result) (local.get $temp)))

    ;; Simulate tree traversal
    (local.set $temp (call $tree_traversal
      (i32.add (local.get $scale) (i32.const 5))
      (i32.mul (local.get $scale) (i32.const 20))
    ))
    (local.set $result (i32.mul (local.get $result) (local.get $temp)))

    (local.get $result)
  )

  ;; Entry point
  (func $_start (export "_start")
    (drop (call $git_simulation_benchmark (i32.const 1)))
  )
)