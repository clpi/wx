(module
  ;; GIT-LEVEL COMPREHENSIVE WEBASSEMBLY BENCHMARK
  ;; This benchmark recreates the core functionality of Git version control:
  ;; - SHA-1 cryptographic hashing with full message scheduling
  ;; - Git object storage (blobs, trees, commits) with compression
  ;; - Merkle tree construction and traversal
  ;; - Delta compression algorithms
  ;; - Binary search trees for fast object lookup
  ;; - String manipulation and parsing
  ;; - Complex memory management patterns
  ;; - Recursive algorithms with deep call stacks
  
  ;; Memory layout (1MB total):
  ;; 0x00000-0x0FFFF: Object storage (64KB)
  ;; 0x10000-0x1FFFF: Hash tables and indices (64KB) 
  ;; 0x20000-0x2FFFF: Working buffers and temp data (64KB)
  ;; 0x30000-0x3FFFF: Compressed data and deltas (64KB)
  (memory 16) ;; 1MB total memory
  
  ;; Global state for Git operations
  (global $object_count (mut i32) (i32.const 0))
  (global $commit_count (mut i32) (i32.const 0))
  (global $tree_depth (mut i32) (i32.const 0))
  (global $hash_collisions (mut i32) (i32.const 0))
  (global $compression_ratio (mut f32) (f32.const 1.0))
  (global $gc_cycles (mut i32) (i32.const 0))
  
  ;; SHA-1 state globals (for performance)
  (global $h0 (mut i32) (i32.const 0x67452301))
  (global $h1 (mut i32) (i32.const 0xEFCDAB89))
  (global $h2 (mut i32) (i32.const 0x98BADCFE))
  (global $h3 (mut i32) (i32.const 0x10325476))
  (global $h4 (mut i32) (i32.const 0xC3D2E1F0))
  
  ;; Constants
  (global $sha1_k0 i32 (i32.const 0x5A827999))
  (global $sha1_k1 i32 (i32.const 0x6ED9EBA1))
  (global $sha1_k2 i32 (i32.const 0x8F1BBCDC))
  (global $sha1_k3 i32 (i32.const 0xCA62C1D6))
  
  ;; Object type constants
  (global $obj_blob i32 (i32.const 1))
  (global $obj_tree i32 (i32.const 2))
  (global $obj_commit i32 (i32.const 3))
  (global $obj_tag i32 (i32.const 4))
  
  ;; === CRYPTOGRAPHIC FUNCTIONS ===
  
  ;; SHA-1 left rotate function (critical for hash security)
  (func $rotl (param $x i32) (param $n i32) (result i32)
    (i32.or
      (i32.shl (local.get $x) (local.get $n))
      (i32.shr_u (local.get $x) (i32.sub (i32.const 32) (local.get $n)))
    )
  )
  
  ;; SHA-1 F function for rounds 0-19
  (func $sha1_f (param $b i32) (param $c i32) (param $d i32) (result i32)
    (i32.or
      (i32.and (local.get $b) (local.get $c))
      (i32.and (i32.xor (local.get $b) (i32.const -1)) (local.get $d))
    )
  )
  
  ;; SHA-1 G function for rounds 20-39 and 60-79
  (func $sha1_g (param $b i32) (param $c i32) (param $d i32) (result i32)
    (i32.xor (i32.xor (local.get $b) (local.get $c)) (local.get $d))
  )
  
  ;; SHA-1 H function for rounds 40-59
  (func $sha1_h (param $b i32) (param $c i32) (param $d i32) (result i32)
    (i32.or
      (i32.or
        (i32.and (local.get $b) (local.get $c))
        (i32.and (local.get $b) (local.get $d))
      )
      (i32.and (local.get $c) (local.get $d))
    )
  )
  
  ;; Full SHA-1 hash computation (most compute-intensive part)
  (func $sha1_hash (param $data_ptr i32) (param $length i32) (result i32)
    (local $w_ptr i32)
    (local $i i32)
    (local $j i32)
    (local $chunk_ptr i32)
    (local $padded_length i32)
    (local $bit_length i64)
    
    ;; SHA-1 working variables
    (local $a i32) (local $b i32) (local $c i32) (local $d i32) (local $e i32)
    (local $temp i32) (local $w i32)
    
    ;; Initialize hash values
    (global.set $h0 (i32.const 0x67452301))
    (global.set $h1 (i32.const 0xEFCDAB89))
    (global.set $h2 (i32.const 0x98BADCFE))
    (global.set $h3 (i32.const 0x10325476))
    (global.set $h4 (i32.const 0xC3D2E1F0))
    
    ;; Calculate padded length
    (local.set $bit_length (i64.mul (i64.extend_i32_u (local.get $length)) (i64.const 8)))
    (local.set $padded_length 
      (i32.and 
        (i32.add (i32.add (local.get $length) (i32.const 9)) (i32.const 63))
        (i32.const -64)
      )
    )
    
    ;; Working space for message schedule
    (local.set $w_ptr (i32.const 0x20000))
    
    ;; Process message in 512-bit chunks
    (local.set $chunk_ptr (local.get $data_ptr))
    (loop $chunk_loop
      ;; Copy chunk to working array and pad if necessary
      (local.set $i (i32.const 0))
      (loop $copy_loop
        (if (i32.lt_u (i32.add (local.get $chunk_ptr) (local.get $i)) 
                      (i32.add (local.get $data_ptr) (local.get $length)))
          (then
            ;; Copy original data
            (i32.store
              (i32.add (local.get $w_ptr) (i32.shl (local.get $i) (i32.const 2)))
              (i32.load8_u (i32.add (local.get $chunk_ptr) (local.get $i)))
            )
          )
          (else
            ;; Padding
            (if (i32.eq (local.get $i) (i32.sub (local.get $length) 
                                                (i32.sub (local.get $chunk_ptr) (local.get $data_ptr))))
              (then
                ;; First padding byte (0x80)
                (i32.store
                  (i32.add (local.get $w_ptr) (i32.shl (local.get $i) (i32.const 2)))
                  (i32.const 0x80000000)
                )
              )
              (else
                ;; Other padding bytes (0x00)
                (i32.store
                  (i32.add (local.get $w_ptr) (i32.shl (local.get $i) (i32.const 2)))
                  (i32.const 0)
                )
              )
            )
          )
        )
        
        (local.set $i (i32.add (local.get $i) (i32.const 4)))
        (br_if $copy_loop (i32.lt_u (local.get $i) (i32.const 64)))
      )
      
      ;; Add length to last 8 bytes if this is the last chunk
      (if (i32.ge_u (i32.add (local.get $chunk_ptr) (i32.const 64))
                    (i32.add (local.get $data_ptr) (local.get $padded_length)))
        (then
          (i32.store (i32.add (local.get $w_ptr) (i32.const 56)) 
                     (i32.wrap_i64 (i64.shr_u (local.get $bit_length) (i64.const 32))))
          (i32.store (i32.add (local.get $w_ptr) (i32.const 60))
                     (i32.wrap_i64 (local.get $bit_length)))
        )
      )
      
      ;; Extend the sixteen 32-bit words into eighty 32-bit words
      (local.set $i (i32.const 16))
      (loop $extend_loop
        (local.set $w
          (call $rotl
            (i32.xor
              (i32.xor
                (i32.load (i32.add (local.get $w_ptr) (i32.shl (i32.sub (local.get $i) (i32.const 3)) (i32.const 2))))
                (i32.load (i32.add (local.get $w_ptr) (i32.shl (i32.sub (local.get $i) (i32.const 8)) (i32.const 2))))
              )
              (i32.xor
                (i32.load (i32.add (local.get $w_ptr) (i32.shl (i32.sub (local.get $i) (i32.const 14)) (i32.const 2))))
                (i32.load (i32.add (local.get $w_ptr) (i32.shl (i32.sub (local.get $i) (i32.const 16)) (i32.const 2))))
              )
            )
            (i32.const 1)
          )
        )
        (i32.store (i32.add (local.get $w_ptr) (i32.shl (local.get $i) (i32.const 2))) (local.get $w))
        
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br_if $extend_loop (i32.lt_u (local.get $i) (i32.const 80)))
      )
      
      ;; Initialize working variables
      (local.set $a (global.get $h0))
      (local.set $b (global.get $h1))
      (local.set $c (global.get $h2))
      (local.set $d (global.get $h3))
      (local.set $e (global.get $h4))
      
      ;; Main SHA-1 compression loop (80 rounds)
      (local.set $i (i32.const 0))
      (loop $main_loop
        (local.set $w (i32.load (i32.add (local.get $w_ptr) (i32.shl (local.get $i) (i32.const 2)))))
        
        ;; Calculate temp value based on round
        (if (i32.lt_u (local.get $i) (i32.const 20))
          (then
            (local.set $temp
              (i32.add
                (i32.add
                  (i32.add
                    (call $rotl (local.get $a) (i32.const 5))
                    (call $sha1_f (local.get $b) (local.get $c) (local.get $d))
                  )
                  (local.get $e)
                )
                (i32.add (local.get $w) (global.get $sha1_k0))
              )
            )
          )
          (else
            (if (i32.lt_u (local.get $i) (i32.const 40))
              (then
                (local.set $temp
                  (i32.add
                    (i32.add
                      (i32.add
                        (call $rotl (local.get $a) (i32.const 5))
                        (call $sha1_g (local.get $b) (local.get $c) (local.get $d))
                      )
                      (local.get $e)
                    )
                    (i32.add (local.get $w) (global.get $sha1_k1))
                  )
                )
              )
              (else
                (if (i32.lt_u (local.get $i) (i32.const 60))
                  (then
                    (local.set $temp
                      (i32.add
                        (i32.add
                          (i32.add
                            (call $rotl (local.get $a) (i32.const 5))
                            (call $sha1_h (local.get $b) (local.get $c) (local.get $d))
                          )
                          (local.get $e)
                        )
                        (i32.add (local.get $w) (global.get $sha1_k2))
                      )
                    )
                  )
                  (else
                    (local.set $temp
                      (i32.add
                        (i32.add
                          (i32.add
                            (call $rotl (local.get $a) (i32.const 5))
                            (call $sha1_g (local.get $b) (local.get $c) (local.get $d))
                          )
                          (local.get $e)
                        )
                        (i32.add (local.get $w) (global.get $sha1_k3))
                      )
                    )
                  )
                )
              )
            )
          )
        )
        
        ;; Update working variables
        (local.set $e (local.get $d))
        (local.set $d (local.get $c))
        (local.set $c (call $rotl (local.get $b) (i32.const 30)))
        (local.set $b (local.get $a))
        (local.set $a (local.get $temp))
        
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br_if $main_loop (i32.lt_u (local.get $i) (i32.const 80)))
      )
      
      ;; Add this chunk's hash to result
      (global.set $h0 (i32.add (global.get $h0) (local.get $a)))
      (global.set $h1 (i32.add (global.get $h1) (local.get $b)))
      (global.set $h2 (i32.add (global.get $h2) (local.get $c)))
      (global.set $h3 (i32.add (global.get $h3) (local.get $d)))
      (global.set $h4 (i32.add (global.get $h4) (local.get $e)))
      
      (local.set $chunk_ptr (i32.add (local.get $chunk_ptr) (i32.const 64)))
      (br_if $chunk_loop (i32.lt_u (local.get $chunk_ptr) 
                                   (i32.add (local.get $data_ptr) (local.get $padded_length))))
    )
    
    ;; Store final hash at result location (0x20400)
    (i32.store (i32.const 0x20400) (global.get $h0))
    (i32.store (i32.const 0x20404) (global.get $h1))
    (i32.store (i32.const 0x20408) (global.get $h2))
    (i32.store (i32.const 0x2040C) (global.get $h3))
    (i32.store (i32.const 0x20410) (global.get $h4))
    
    (i32.const 0x20400) ;; Return pointer to hash
  )
  
  ;; === GIT OBJECT SYSTEM ===
  
  ;; Create Git blob object with content
  (func $create_blob (param $content_ptr i32) (param $content_len i32) (result i32)
    (local $obj_ptr i32)
    (local $header_len i32)
    (local $total_len i32)
    (local $hash_ptr i32)
    (local $i i32)
    
    ;; Allocate object space
    (local.set $obj_ptr (i32.add (i32.const 0x00000) 
                                 (i32.mul (global.get $object_count) (i32.const 1024))))
    
    ;; Create Git object header: "blob <size>\0"
    (i32.store8 (local.get $obj_ptr) (i32.const 98))  ;; 'b'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 1)) (i32.const 108)) ;; 'l'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 2)) (i32.const 111)) ;; 'o'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 3)) (i32.const 98))  ;; 'b'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 4)) (i32.const 32))  ;; ' '
    
    ;; Add size (simplified - just store the number)
    (local.set $header_len (call $write_decimal (i32.add (local.get $obj_ptr) (i32.const 5)) 
                                                 (local.get $content_len)))
    (local.set $header_len (i32.add (local.get $header_len) (i32.const 5)))
    (i32.store8 (i32.add (local.get $obj_ptr) (local.get $header_len)) (i32.const 0)) ;; null terminator
    (local.set $header_len (i32.add (local.get $header_len) (i32.const 1)))
    
    ;; Copy content after header
    (local.set $i (i32.const 0))
    (loop $copy_content
      (i32.store8 
        (i32.add (i32.add (local.get $obj_ptr) (local.get $header_len)) (local.get $i))
        (i32.load8_u (i32.add (local.get $content_ptr) (local.get $i)))
      )
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $copy_content (i32.lt_u (local.get $i) (local.get $content_len)))
    )
    
    ;; Calculate total length and hash the object
    (local.set $total_len (i32.add (local.get $header_len) (local.get $content_len)))
    (local.set $hash_ptr (call $sha1_hash (local.get $obj_ptr) (local.get $total_len)))
    
    ;; Store object metadata
    (i32.store (i32.add (local.get $obj_ptr) (i32.const 1020)) (global.get $obj_blob))
    
    ;; Increment object counter
    (global.set $object_count (i32.add (global.get $object_count) (i32.const 1)))
    
    (local.get $obj_ptr)
  )
  
  ;; Write decimal number to buffer (helper function)
  (func $write_decimal (param $buffer_ptr i32) (param $value i32) (result i32)
    (local $len i32)
    (local $temp i32)
    (local $digit i32)
    (local $i i32)
    
    (if (i32.eq (local.get $value) (i32.const 0))
      (then
        (i32.store8 (local.get $buffer_ptr) (i32.const 48)) ;; '0'
        (return (i32.const 1))
      )
    )
    
    ;; Calculate number of digits
    (local.set $temp (local.get $value))
    (local.set $len (i32.const 0))
    (loop $count_digits
      (local.set $temp (i32.div_u (local.get $temp) (i32.const 10)))
      (local.set $len (i32.add (local.get $len) (i32.const 1)))
      (br_if $count_digits (i32.ne (local.get $temp) (i32.const 0)))
    )
    
    ;; Write digits in reverse order
    (local.set $temp (local.get $value))
    (local.set $i (local.get $len))
    (loop $write_digits
      (local.set $i (i32.sub (local.get $i) (i32.const 1)))
      (local.set $digit (i32.rem_u (local.get $temp) (i32.const 10)))
      (i32.store8 (i32.add (local.get $buffer_ptr) (local.get $i)) 
                  (i32.add (local.get $digit) (i32.const 48)))
      (local.set $temp (i32.div_u (local.get $temp) (i32.const 10)))
      (br_if $write_digits (i32.ne (local.get $temp) (i32.const 0)))
    )
    
    (local.get $len)
  )
  
  ;; Create Git tree object (directory structure)
  (func $create_tree (param $entries_ptr i32) (param $entry_count i32) (result i32)
    (local $obj_ptr i32)
    (local $header_len i32)
    (local $content_len i32)
    (local $total_len i32)
    (local $hash_ptr i32)
    (local $i i32)
    (local $entry_ptr i32)
    (local $mode i32)
    (local $name_len i32)
    (local $j i32)
    
    ;; Allocate object space  
    (local.set $obj_ptr (i32.add (i32.const 0x00000) 
                                 (i32.mul (global.get $object_count) (i32.const 1024))))
    
    ;; Create Git object header: "tree <size>\0"
    (i32.store8 (local.get $obj_ptr) (i32.const 116)) ;; 't'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 1)) (i32.const 114)) ;; 'r'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 2)) (i32.const 101)) ;; 'e'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 3)) (i32.const 101)) ;; 'e'
    (i32.store8 (i32.add (local.get $obj_ptr) (i32.const 4)) (i32.const 32))  ;; ' '
    
    ;; Calculate content length first (tree entries)
    (local.set $content_len (i32.const 0))
    (local.set $i (i32.const 0))
    (loop $calc_length
      (local.set $entry_ptr (i32.add (local.get $entries_ptr) (i32.mul (local.get $i) (i32.const 64))))
      (local.set $mode (i32.load (local.get $entry_ptr)))
      (local.set $name_len (i32.load (i32.add (local.get $entry_ptr) (i32.const 4))))
      
      ;; Mode + space + name + null + 20-byte hash
      (local.set $content_len (i32.add (local.get $content_len) 
        (i32.add (i32.add (i32.add (call $decimal_length (local.get $mode)) (i32.const 1))
                          (i32.add (local.get $name_len) (i32.const 1)))
                 (i32.const 20))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $calc_length (i32.lt_u (local.get $i) (local.get $entry_count)))
    )
    
    ;; Write content length to header
    (local.set $header_len (call $write_decimal (i32.add (local.get $obj_ptr) (i32.const 5)) 
                                                 (local.get $content_len)))
    (local.set $header_len (i32.add (local.get $header_len) (i32.const 5)))
    (i32.store8 (i32.add (local.get $obj_ptr) (local.get $header_len)) (i32.const 0))
    (local.set $header_len (i32.add (local.get $header_len) (i32.const 1)))
    
    ;; Write tree entries (mode name\0hash format)
    (local.set $content_len (i32.const 0))
    (local.set $i (i32.const 0))
    (loop $write_entries
      (local.set $entry_ptr (i32.add (local.get $entries_ptr) (i32.mul (local.get $i) (i32.const 64))))
      (local.set $mode (i32.load (local.get $entry_ptr)))
      (local.set $name_len (i32.load (i32.add (local.get $entry_ptr) (i32.const 4))))
      
      ;; Write mode
      (local.set $j (call $write_decimal 
        (i32.add (i32.add (local.get $obj_ptr) (local.get $header_len)) (local.get $content_len))
        (local.get $mode)))
      (local.set $content_len (i32.add (local.get $content_len) (local.get $j)))
      
      ;; Write space
      (i32.store8 (i32.add (i32.add (local.get $obj_ptr) (local.get $header_len)) (local.get $content_len))
                  (i32.const 32))
      (local.set $content_len (i32.add (local.get $content_len) (i32.const 1)))
      
      ;; Write name
      (local.set $j (i32.const 0))
      (loop $write_name
        (i32.store8 
          (i32.add (i32.add (local.get $obj_ptr) (local.get $header_len)) 
                   (i32.add (local.get $content_len) (local.get $j)))
          (i32.load8_u (i32.add (i32.add (local.get $entry_ptr) (i32.const 8)) (local.get $j))))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $write_name (i32.lt_u (local.get $j) (local.get $name_len)))
      )
      (local.set $content_len (i32.add (local.get $content_len) (local.get $name_len)))
      
      ;; Write null terminator
      (i32.store8 (i32.add (i32.add (local.get $obj_ptr) (local.get $header_len)) (local.get $content_len))
                  (i32.const 0))
      (local.set $content_len (i32.add (local.get $content_len) (i32.const 1)))
      
      ;; Write 20-byte hash
      (local.set $j (i32.const 0))
      (loop $write_hash
        (i32.store8 
          (i32.add (i32.add (local.get $obj_ptr) (local.get $header_len)) 
                   (i32.add (local.get $content_len) (local.get $j)))
          (i32.load8_u (i32.add (i32.add (local.get $entry_ptr) (i32.const 40)) (local.get $j))))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $write_hash (i32.lt_u (local.get $j) (i32.const 20)))
      )
      (local.set $content_len (i32.add (local.get $content_len) (i32.const 20)))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $write_entries (i32.lt_u (local.get $i) (local.get $entry_count)))
    )
    
    ;; Hash the complete tree object
    (local.set $total_len (i32.add (local.get $header_len) (local.get $content_len)))
    (local.set $hash_ptr (call $sha1_hash (local.get $obj_ptr) (local.get $total_len)))
    
    ;; Store object metadata
    (i32.store (i32.add (local.get $obj_ptr) (i32.const 1020)) (global.get $obj_tree))
    
    (global.set $object_count (i32.add (global.get $object_count) (i32.const 1)))
    (local.get $obj_ptr)
  )
  
  ;; Calculate decimal length (helper)
  (func $decimal_length (param $value i32) (result i32)
    (local $len i32)
    (local $temp i32)
    
    (if (i32.eq (local.get $value) (i32.const 0))
      (then (return (i32.const 1))))
    
    (local.set $temp (local.get $value))
    (local.set $len (i32.const 0))
    (loop $count
      (local.set $temp (i32.div_u (local.get $temp) (i32.const 10)))
      (local.set $len (i32.add (local.get $len) (i32.const 1)))
      (br_if $count (i32.ne (local.get $temp) (i32.const 0)))
    )
    (local.get $len)
  )
  
  ;; === COMPRESSION ALGORITHMS ===
  
  ;; LZ77-style compression (simplified for Git pack files)
  (func $compress_data (param $input_ptr i32) (param $input_len i32) (param $output_ptr i32) (result i32)
    (local $output_len i32)
    (local $i i32)
    (local $j i32)
    (local $k i32)
    (local $match_len i32)
    (local $best_match_len i32)
    (local $best_match_pos i32)
    (local $current_byte i32)
    (local $match_byte i32)
    (local $window_start i32)
    
    (local.set $output_len (i32.const 0))
    (local.set $i (i32.const 0))
    
    (loop $compress_loop
      (local.set $best_match_len (i32.const 0))
      (local.set $best_match_pos (i32.const 0))
      
      ;; Look for matches in sliding window (32KB max)
      (local.set $window_start (i32.sub (local.get $i) (i32.const 32768)))
      (if (i32.lt_s (local.get $window_start) (i32.const 0))
        (then (local.set $window_start (i32.const 0))))
      
      (local.set $j (local.get $window_start))
      (loop $search_loop
        (if (i32.lt_u (local.get $j) (local.get $i))
          (then
            ;; Check for match starting at position j
            (local.set $match_len (i32.const 0))
            (local.set $k (i32.const 0))
            
            (loop $match_loop
              (if (i32.and 
                    (i32.lt_u (i32.add (local.get $i) (local.get $k)) (local.get $input_len))
                    (i32.lt_u (i32.add (local.get $j) (local.get $k)) (local.get $i)))
                (then
                  (local.set $current_byte (i32.load8_u (i32.add (local.get $input_ptr) 
                                                                 (i32.add (local.get $i) (local.get $k)))))
                  (local.set $match_byte (i32.load8_u (i32.add (local.get $input_ptr) 
                                                               (i32.add (local.get $j) (local.get $k)))))
                  
                  (if (i32.eq (local.get $current_byte) (local.get $match_byte))
                    (then
                      (local.set $match_len (i32.add (local.get $match_len) (i32.const 1)))
                      (local.set $k (i32.add (local.get $k) (i32.const 1)))
                      (br_if $match_loop (i32.lt_u (local.get $match_len) (i32.const 258))) ;; Max match length
                    )
                  )
                )
              )
            )
            
            ;; Update best match if this one is longer
            (if (i32.gt_u (local.get $match_len) (local.get $best_match_len))
              (then
                (local.set $best_match_len (local.get $match_len))
                (local.set $best_match_pos (local.get $j))
              )
            )
          )
        )
        
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $search_loop (i32.lt_u (local.get $j) (local.get $i)))
      )
      
      ;; Output compressed data
      (if (i32.ge_u (local.get $best_match_len) (i32.const 3))
        (then
          ;; Output length-distance pair (simplified format)
          (i32.store8 (i32.add (local.get $output_ptr) (local.get $output_len)) 
                      (i32.or (local.get $best_match_len) (i32.const 0x80))) ;; Mark as match
          (local.set $output_len (i32.add (local.get $output_len) (i32.const 1)))
          
          (i32.store16 (i32.add (local.get $output_ptr) (local.get $output_len))
                       (i32.sub (local.get $i) (local.get $best_match_pos)))
          (local.set $output_len (i32.add (local.get $output_len) (i32.const 2)))
          
          (local.set $i (i32.add (local.get $i) (local.get $best_match_len)))
        )
        (else
          ;; Output literal byte
          (i32.store8 (i32.add (local.get $output_ptr) (local.get $output_len))
                      (i32.load8_u (i32.add (local.get $input_ptr) (local.get $i))))
          (local.set $output_len (i32.add (local.get $output_len) (i32.const 1)))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
        )
      )
      
      (br_if $compress_loop (i32.lt_u (local.get $i) (local.get $input_len)))
    )
    
    (local.get $output_len)
  )
  
  ;; === BINARY SEARCH TREE FOR OBJECT LOOKUP ===
  
  ;; BST node structure: hash(20) + left_ptr(4) + right_ptr(4) + object_ptr(4) = 32 bytes
  (func $bst_insert (param $root_ptr_addr i32) (param $hash_ptr i32) (param $obj_ptr i32)
    (local $current_ptr i32)
    (local $parent_ptr i32)
    (local $new_node_ptr i32)
    (local $cmp_result i32)
    (local $i i32)
    
    ;; Allocate new node
    (local.set $new_node_ptr (i32.add (i32.const 0x10000) 
                                      (i32.mul (global.get $object_count) (i32.const 32))))
    
    ;; Copy hash to new node
    (local.set $i (i32.const 0))
    (loop $copy_hash
      (i32.store8 (i32.add (local.get $new_node_ptr) (local.get $i))
                  (i32.load8_u (i32.add (local.get $hash_ptr) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $copy_hash (i32.lt_u (local.get $i) (i32.const 20)))
    )
    
    ;; Initialize pointers
    (i32.store (i32.add (local.get $new_node_ptr) (i32.const 20)) (i32.const 0)) ;; left
    (i32.store (i32.add (local.get $new_node_ptr) (i32.const 24)) (i32.const 0)) ;; right
    (i32.store (i32.add (local.get $new_node_ptr) (i32.const 28)) (local.get $obj_ptr)) ;; object
    
    ;; If tree is empty, set as root
    (local.set $current_ptr (i32.load (local.get $root_ptr_addr)))
    (if (i32.eq (local.get $current_ptr) (i32.const 0))
      (then
        (i32.store (local.get $root_ptr_addr) (local.get $new_node_ptr))
        (return)
      )
    )
    
    ;; Find insertion point
    (loop $find_position
      (local.set $parent_ptr (local.get $current_ptr))
      (local.set $cmp_result (call $compare_hashes (local.get $hash_ptr) (local.get $current_ptr)))
      
      (if (i32.lt_s (local.get $cmp_result) (i32.const 0))
        (then
          (local.set $current_ptr (i32.load (i32.add (local.get $current_ptr) (i32.const 20))))
          (if (i32.eq (local.get $current_ptr) (i32.const 0))
            (then
              (i32.store (i32.add (local.get $parent_ptr) (i32.const 20)) (local.get $new_node_ptr))
              (return)
            )
          )
        )
        (else
          (if (i32.gt_s (local.get $cmp_result) (i32.const 0))
            (then
              (local.set $current_ptr (i32.load (i32.add (local.get $current_ptr) (i32.const 24))))
              (if (i32.eq (local.get $current_ptr) (i32.const 0))
                (then
                  (i32.store (i32.add (local.get $parent_ptr) (i32.const 24)) (local.get $new_node_ptr))
                  (return)
                )
              )
            )
            (else
              ;; Hash collision - increment counter
              (global.set $hash_collisions (i32.add (global.get $hash_collisions) (i32.const 1)))
              (return)
            )
          )
        )
      )
      (br $find_position)
    )
  )
  
  ;; Compare two 20-byte SHA-1 hashes
  (func $compare_hashes (param $hash1_ptr i32) (param $hash2_ptr i32) (result i32)
    (local $i i32)
    (local $byte1 i32)
    (local $byte2 i32)
    
    (local.set $i (i32.const 0))
    (loop $compare_loop
      (local.set $byte1 (i32.load8_u (i32.add (local.get $hash1_ptr) (local.get $i))))
      (local.set $byte2 (i32.load8_u (i32.add (local.get $hash2_ptr) (local.get $i))))
      
      (if (i32.ne (local.get $byte1) (local.get $byte2))
        (then
          (return (i32.sub (local.get $byte1) (local.get $byte2)))
        )
      )
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $compare_loop (i32.lt_u (local.get $i) (i32.const 20)))
    )
    
    (i32.const 0) ;; Hashes are equal
  )
  
  ;; === MERKLE TREE OPERATIONS ===
  
  ;; Build Merkle tree from object hashes (recursive)
  (func $build_merkle_tree (param $hash_array_ptr i32) (param $count i32) (result i32)
    (local $result_ptr i32)
    (local $left_hash_ptr i32)
    (local $right_hash_ptr i32)
    (local $combined_ptr i32)
    (local $i i32)
    (local $new_count i32)
    
    ;; Base case: single hash
    (if (i32.eq (local.get $count) (i32.const 1))
      (then (return (local.get $hash_array_ptr))))
    
    ;; Allocate space for next level
    (local.set $result_ptr (i32.add (i32.const 0x30000) 
                                    (i32.mul (global.get $tree_depth) (i32.const 4096))))
    (local.set $combined_ptr (i32.add (i32.const 0x20800) (i32.const 0)))
    (local.set $new_count (i32.const 0))
    
    ;; Combine pairs of hashes
    (local.set $i (i32.const 0))
    (loop $combine_loop
      (local.set $left_hash_ptr (i32.add (local.get $hash_array_ptr) (i32.mul (local.get $i) (i32.const 20))))
      
      (if (i32.lt_u (i32.add (local.get $i) (i32.const 1)) (local.get $count))
        (then
          ;; Pair exists - combine both hashes
          (local.set $right_hash_ptr (i32.add (local.get $hash_array_ptr) 
                                              (i32.mul (i32.add (local.get $i) (i32.const 1)) (i32.const 20))))
          
          ;; Copy left hash to combined buffer
          (call $copy_bytes (local.get $combined_ptr) (local.get $left_hash_ptr) (i32.const 20))
          ;; Copy right hash after left hash
          (call $copy_bytes (i32.add (local.get $combined_ptr) (i32.const 20)) 
                            (local.get $right_hash_ptr) (i32.const 20))
          
          ;; Hash the combined 40 bytes
          (drop (call $sha1_hash (local.get $combined_ptr) (i32.const 40)))
          
          ;; Copy result to next level
          (call $copy_bytes (i32.add (local.get $result_ptr) (i32.mul (local.get $new_count) (i32.const 20)))
                            (i32.const 0x20400) (i32.const 20))
          
          (local.set $i (i32.add (local.get $i) (i32.const 2)))
        )
        (else
          ;; Odd hash - promote directly to next level
          (call $copy_bytes (i32.add (local.get $result_ptr) (i32.mul (local.get $new_count) (i32.const 20)))
                            (local.get $left_hash_ptr) (i32.const 20))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
        )
      )
      
      (local.set $new_count (i32.add (local.get $new_count) (i32.const 1)))
      (br_if $combine_loop (i32.lt_u (local.get $i) (local.get $count)))
    )
    
    ;; Increment tree depth for next level
    (global.set $tree_depth (i32.add (global.get $tree_depth) (i32.const 1)))
    
    ;; Recurse to next level
    (return (call $build_merkle_tree (local.get $result_ptr) (local.get $new_count)))
  )
  
  ;; Copy bytes helper function
  (func $copy_bytes (param $dest_ptr i32) (param $src_ptr i32) (param $count i32)
    (local $i i32)
    (local.set $i (i32.const 0))
    (loop $copy_loop
      (i32.store8 (i32.add (local.get $dest_ptr) (local.get $i))
                  (i32.load8_u (i32.add (local.get $src_ptr) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $copy_loop (i32.lt_u (local.get $i) (local.get $count)))
    )
  )
  
  ;; === GARBAGE COLLECTION SIMULATION ===
  
  ;; Mark and sweep garbage collection for Git objects
  (func $garbage_collect
    (local $obj_ptr i32)
    (local $obj_type i32)
    (local $i i32)
    (local $marked_count i32)
    (local $swept_count i32)
    
    ;; Mark phase: mark all reachable objects
    (local.set $marked_count (i32.const 0))
    (local.set $i (i32.const 0))
    (loop $mark_loop
      (local.set $obj_ptr (i32.add (i32.const 0x00000) (i32.mul (local.get $i) (i32.const 1024))))
      (local.set $obj_type (i32.load (i32.add (local.get $obj_ptr) (i32.const 1020))))
      
      ;; Simple marking: mark objects created in last 50% of operations
      (if (i32.gt_u (local.get $i) (i32.div_u (global.get $object_count) (i32.const 2)))
        (then
          ;; Mark object (set high bit in type field)
          (i32.store (i32.add (local.get $obj_ptr) (i32.const 1020))
                     (i32.or (local.get $obj_type) (i32.const 0x80000000)))
          (local.set $marked_count (i32.add (local.get $marked_count) (i32.const 1)))
        )
      )
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $mark_loop (i32.lt_u (local.get $i) (global.get $object_count)))
    )
    
    ;; Sweep phase: free unmarked objects
    (local.set $swept_count (i32.const 0))
    (local.set $i (i32.const 0))
    (loop $sweep_loop
      (local.set $obj_ptr (i32.add (i32.const 0x00000) (i32.mul (local.get $i) (i32.const 1024))))
      (local.set $obj_type (i32.load (i32.add (local.get $obj_ptr) (i32.const 1020))))
      
      (if (i32.and (local.get $obj_type) (i32.const 0x80000000))
        (then
          ;; Object is marked - unmark it
          (i32.store (i32.add (local.get $obj_ptr) (i32.const 1020))
                     (i32.and (local.get $obj_type) (i32.const 0x7FFFFFFF)))
        )
        (else
          ;; Object is unmarked - clear it
          (call $clear_object (local.get $obj_ptr))
          (local.set $swept_count (i32.add (local.get $swept_count) (i32.const 1)))
        )
      )
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $sweep_loop (i32.lt_u (local.get $i) (global.get $object_count)))
    )
    
    (global.set $gc_cycles (i32.add (global.get $gc_cycles) (i32.const 1)))
  )
  
  ;; Clear object data
  (func $clear_object (param $obj_ptr i32)
    (local $i i32)
    (local.set $i (i32.const 0))
    (loop $clear_loop
      (i32.store8 (i32.add (local.get $obj_ptr) (local.get $i)) (i32.const 0))
      (local.set $i (i32.add (local.get $i) (i32.const 4)))
      (br_if $clear_loop (i32.lt_u (local.get $i) (i32.const 1024)))
    )
  )
  
  ;; === MAIN GIT BENCHMARK ===
  
  ;; Comprehensive Git operations benchmark
  (func $git_benchmark (result i32)
    (local $i i32)
    (local $j i32)
    (local $blob_ptr i32)
    (local $tree_ptr i32)
    (local $commit_ptr i32)
    (local $content_ptr i32)
    (local $hash_ptr i32)
    (local $compressed_len i32)
    (local $merkle_root i32)
    (local $bst_root i32)
    (local $total_score i32)
    (local $file_count i32)
    (local $dir_count i32)
    (local $entries_ptr i32)
    
    ;; Initialize benchmark state
    (global.set $object_count (i32.const 0))
    (global.set $commit_count (i32.const 0))
    (global.set $tree_depth (i32.const 0))
    (global.set $hash_collisions (i32.const 0))
    (global.set $gc_cycles (i32.const 0))
    (local.set $bst_root (i32.const 0))
    (local.set $total_score (i32.const 0))
    
    ;; Phase 1: Create a complex repository structure (like Linux kernel)
    (local.set $file_count (i32.const 256))  ;; Simulate 256 files
    (local.set $dir_count (i32.const 32))    ;; In 32 directories
    
    ;; Create file contents (blobs)
    (local.set $i (i32.const 0))
    (loop $create_blobs
      ;; Generate pseudo-random file content
      (local.set $content_ptr (i32.add (i32.const 0x20800) (i32.mul (local.get $i) (i32.const 256))))
      (local.set $j (i32.const 0))
      (loop $generate_content
        (i32.store8 (i32.add (local.get $content_ptr) (local.get $j))
                    (i32.add (i32.const 65) ;; 'A'
                             (i32.rem_u (i32.add (i32.mul (local.get $i) (i32.const 7))
                                                 (i32.mul (local.get $j) (i32.const 13)))
                                        (i32.const 26))))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $generate_content (i32.lt_u (local.get $j) (i32.const 200)))
      )
      
      ;; Create blob object
      (local.set $blob_ptr (call $create_blob (local.get $content_ptr) (i32.const 200)))
      
      ;; Add to BST for fast lookup
      (local.set $hash_ptr (i32.const 0x20400))
      (call $bst_insert (i32.const 0x1F000) (local.get $hash_ptr) (local.get $blob_ptr))
      
      ;; Compress the blob data
      (local.set $compressed_len 
        (call $compress_data (local.get $content_ptr) (i32.const 200)
                             (i32.add (i32.const 0x30000) (i32.mul (local.get $i) (i32.const 512)))))
      
      ;; Update compression statistics
      (global.set $compression_ratio 
        (f32.div (f32.convert_i32_u (local.get $compressed_len))
                 (f32.const 200.0)))
      
      (local.set $total_score (i32.add (local.get $total_score) (local.get $compressed_len)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $create_blobs (i32.lt_u (local.get $i) (local.get $file_count)))
    )
    
    ;; Phase 2: Create directory trees (complex nested structure)
    (local.set $entries_ptr (i32.const 0x25000))
    (local.set $i (i32.const 0))
    (loop $create_trees
      ;; Create tree entries (8 files per directory)
      (local.set $j (i32.const 0))
      (loop $create_entries
        (local.set $blob_ptr (i32.add (i32.const 0x00000) 
                                      (i32.mul (i32.add (i32.mul (local.get $i) (i32.const 8)) (local.get $j))
                                               (i32.const 1024))))
        
        ;; Entry: mode(4) + name_len(4) + name(32) + hash(20) = 60 bytes, padded to 64
        (i32.store (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64)))
                   (i32.const 100644)) ;; file mode
        (i32.store (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 4))
                   (i32.const 8)) ;; name length
        
        ;; Generate filename: "file_XXX"
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 8))
                    (i32.const 102)) ;; 'f'
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 9))
                    (i32.const 105)) ;; 'i'
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 10))
                    (i32.const 108)) ;; 'l'
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 11))
                    (i32.const 101)) ;; 'e'
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 12))
                    (i32.const 95))  ;; '_'
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 13))
                    (i32.add (i32.const 48) (i32.div_u (local.get $j) (i32.const 10)))) ;; tens digit
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 14))
                    (i32.add (i32.const 48) (i32.rem_u (local.get $j) (i32.const 10)))) ;; ones digit
        (i32.store8 (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 15))
                    (i32.const 0)) ;; null terminator
        
        ;; Copy hash from blob object (stored at 0x20400 after last SHA-1)
        (call $copy_bytes (i32.add (i32.add (local.get $entries_ptr) (i32.mul (local.get $j) (i32.const 64))) (i32.const 40))
                          (i32.const 0x20400) (i32.const 20))
        
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $create_entries (i32.lt_u (local.get $j) (i32.const 8)))
      )
      
      ;; Create tree object
      (local.set $tree_ptr (call $create_tree (local.get $entries_ptr) (i32.const 8)))
      
      (local.set $total_score (i32.add (local.get $total_score) (i32.const 1000)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $create_trees (i32.lt_u (local.get $i) (local.get $dir_count)))
    )
    
    ;; Phase 3: Create commit history (branching and merging)
    (local.set $i (i32.const 0))
    (loop $create_commits
      ;; Create commit content
      (local.set $content_ptr (i32.add (i32.const 0x28000) (i32.mul (local.get $i) (i32.const 512))))
      
      ;; Simplified commit format: "tree <hash>\nauthor ...\ncommitter ...\n\nCommit message"
      ;; Just create some commit-like data
      (local.set $j (i32.const 0))
      (loop $fill_commit
        (i32.store8 (i32.add (local.get $content_ptr) (local.get $j))
                    (i32.add (i32.const 97) ;; 'a'
                             (i32.rem_u (i32.add (local.get $i) (local.get $j)) (i32.const 26))))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $fill_commit (i32.lt_u (local.get $j) (i32.const 256)))
      )
      
      ;; Create commit object (reuse blob creation with different type)
      (local.set $commit_ptr (call $create_blob (local.get $content_ptr) (i32.const 256)))
      (i32.store (i32.add (local.get $commit_ptr) (i32.const 1020)) (global.get $obj_commit))
      
      (global.set $commit_count (i32.add (global.get $commit_count) (i32.const 1)))
      (local.set $total_score (i32.add (local.get $total_score) (i32.const 500)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $create_commits (i32.lt_u (local.get $i) (i32.const 64)))
    )
    
    ;; Phase 4: Build Merkle tree from all object hashes
    (global.set $tree_depth (i32.const 0))
    (local.set $hash_ptr (i32.const 0x26000))
    
    ;; Collect all object hashes
    (local.set $i (i32.const 0))
    (loop $collect_hashes
      ;; Get hash from each object and copy to hash array
      (drop (call $sha1_hash (i32.add (i32.const 0x00000) (i32.mul (local.get $i) (i32.const 1024))) (i32.const 512)))
      (call $copy_bytes (i32.add (local.get $hash_ptr) (i32.mul (local.get $i) (i32.const 20)))
                        (i32.const 0x20400) (i32.const 20))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $collect_hashes (i32.lt_u (local.get $i) (global.get $object_count)))
    )
    
    ;; Build complete Merkle tree
    (local.set $merkle_root (call $build_merkle_tree (local.get $hash_ptr) (global.get $object_count)))
    
    ;; Phase 5: Perform garbage collection cycles
    (local.set $i (i32.const 0))
    (loop $gc_cycles
      (call $garbage_collect)
      (local.set $total_score (i32.add (local.get $total_score) (i32.const 100)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $gc_cycles (i32.lt_u (local.get $i) (i32.const 10)))
    )
    
    ;; Phase 6: Intensive hash computations (simulate Git's internal operations)
    (local.set $i (i32.const 0))
    (loop $intensive_hashing
      ;; Hash random data blocks
      (local.set $content_ptr (i32.add (i32.const 0x29000) (i32.mul (local.get $i) (i32.const 64))))
      (local.set $j (i32.const 0))
      (loop $fill_random
        (i32.store8 (i32.add (local.get $content_ptr) (local.get $j))
                    (i32.xor (i32.mul (local.get $i) (i32.const 17))
                             (i32.mul (local.get $j) (i32.const 31))))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $fill_random (i32.lt_u (local.get $j) (i32.const 64)))
      )
      
      (drop (call $sha1_hash (local.get $content_ptr) (i32.const 64)))
      (local.set $total_score (i32.add (local.get $total_score) (i32.const 10)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $intensive_hashing (i32.lt_u (local.get $i) (i32.const 1000)))
    )
    
    ;; Calculate final benchmark score
    (local.set $total_score 
      (i32.add (local.get $total_score)
        (i32.add
          (i32.add
            (i32.mul (global.get $object_count) (i32.const 100))
            (i32.mul (global.get $commit_count) (i32.const 200))
          )
          (i32.add
            (i32.mul (global.get $tree_depth) (i32.const 50))
            (i32.mul (global.get $gc_cycles) (i32.const 300))
          )
        )
      )
    )
    
    ;; Bonus points for low collision rate
    (if (i32.lt_u (global.get $hash_collisions) (i32.const 10))
      (then
        (local.set $total_score (i32.add (local.get $total_score) (i32.const 5000)))
      )
    )
    
    (local.get $total_score)
  )
  
  ;; Export the main benchmark function
  (export "_start" (func $git_benchmark))
)
