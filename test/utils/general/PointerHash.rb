
require_relative '../../../src/utils/general/PointerHash'

pointer_hash = KLib::PointerHash.new

x = pointer_hash.set(1)
pointer_hash.set(2)

pointer_hash[1] = 1

puts(x.val)

puts(pointer_hash.to_h.inspect)
