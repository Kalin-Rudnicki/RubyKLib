# RubyKLib
This is an assortment of utilities for Ruby to make doing common and/or tedious tasks easier.  

### Main Attractions
[CLI - Command Line Interface](#cli)  
[ArgumentChecking](#argumentchecking)  
[HashNormalizer](#hashnormalizer)  
[Logger](#logger)  

### Documentation

#### CLI

```ruby
module Ex
   cli_spec do |spec|
      spec.symbol(:my_sym)
      spec.integer(:my_int)
      spec.boolean(:my_bool, positive: :use, negative: :ignore) # --(use/ignore)-my-bool
      spec.flag(:my_flag, default: false)

      spec.execute do
         puts("You ran my program")
         show_params # prints out all params
         # parameters are accessed as instance variables
         puts(@my_sym.inspect)
         puts(@my_int.inspect)
         puts(@my_bool.inspect)
         puts(@my_flag.inspect)
      end
   end
end

Ex.parse
```

#### ArgumentChecking
```ruby
def self.type_check(obj, name *valid_types); end
KLib::ArgumentChecking.type_check(my_int, :my_int, Integer)
KLib::ArgumentChecking.type_check(my_str_or_sym, :my_str_or_sym, String, Symbol)
```

```ruby
def self.type_check_each(obj, name, *valid_types)
  type_check(obj, name, Enumerable)
  obj.each_with_index { |e, i| type_check(e, :"#{name}[#{i}]", *valid_types) }
end
KLib::ArgumentChecking.type_check_each(my_strings, :my_strings, String)
```

```ruby
def self.enum_check(obj, name, *valid_values); end
KLib::ArgumentChecking.enum_check(my_sym, :my_sym, :first, :last, :all)
```

```ruby
def self.enum_check_each(obj, name, *valid_types)
  type_check(obj, name, Enumerable)
  obj.each_with_index { |e, i| enum_check(e, :"#{name}[#{i}]", *valid_types) }
end
KLib::ArgumentChecking.enum_check_each(my_syms, :my_sym, :ex_1, :ex_2, :ex_3, :ex_4)
```

```ruby
def self.nil_check(obj, name); end
KLib::ArgumentChecking.nil_check(obj, :obj)
```

```ruby
def self.boolean_check(obj, name)
  type_check(obj, name, TrueClass, FalseClass)
end
KLib::ArgumentChecking.boolean_check(bool, :bool)
```

```ruby
def self.logger_check(obj, name = :logger)
  type_check(obj, name, KLib::Logger, KLib::DeadObject) # KLib::DeadObject does nothing on any methods
end
KLib::ArgumentChecking.logger_check(logger)
```

```ruby
def self.path_check(path, name, type = :any)
  enum_check(type, :type, %i{any file dir exe})
  # ...
end
KLib::ArgumentChecking.path_check(my_path, :my_path)
KLib::ArgumentChecking.path_check(my_path, :my_path, :file)
KLib::ArgumentChecking.path_check(my_path, :my_path, :dir)
KLib::ArgumentChecking.path_check(my_path, :my_path, :exe)
```

```
All of these methods also accept a block.  
The result of this block should be a 'String' or 'Klib::ArgumentChecking::ArgumentCheckError', which will then be raised.  
If the result is 'nil', then the method will simply return false instead of raising and error.  
You can also choose to raise your own error in the block, which is fine, but goes against the way this is intended to be used.  
```

#### HashNormalizer
```ruby
hash_args = KLib::HashNormalizer.normalize(hash_args) do |norm|
   norm.my_long_key_name(:alias_1, :alias_2)

   norm.key_1.no_default # hash_args.key?(:key_1) => false, if not provided
   norm.key_2.required # error, if not provided
   norm.key_3.default_value(:abc) # hash_args[:key_3] => :abc, if not provided
   norm.key_4.default_from(:key_3) # hash_args[:key_4] == hash_args[:key_3], if not provided, :abc if :key_3 not provided either

   norm.key_5.type_check(Integer).validate { |val| val > 5 }
   norm.key_6.type_check(Integer).validate("key_6 is not greater than 6") { |val| val > 6 }
   norm.key_7.type_check(Integer).validate(proc { |val| "key_7: #{val} is not greater than 7" }) { |val| val > 7 }
   
   norm.key_8.enum_check(:val_1, :val_2, :val_3) # all methods can be called from ArgumentChecking, automatically fills in obj and name
end
```

#### Logger
```ruby
# DEFAULT_LOG_LEVELS = %i{never debug detailed info print important warning error fatal always off}
logger = KLib::Logger.new(tolerance: :detailed)
logger.log(:debug, "This wont be shown")
logger.debug("Neither will this")
logger.detailed("But this will")
logger.always("And so will this")

logger.indent do
   logger.print("This will be indented")
end
```

#### GnuMatch
```ruby
def self.match(string, options); end
KLib::GnuMatch.match("str", %w{string strong stuff}) # => nil
$gnu_matches # => %w{string strong}
KLib::GnuMatch.match("stro", %w{string strong stuff}) # => "strong"

KLib::GnuMatch.match("s-1", %w{str-1 sym-1 str-2}) # => nil
$gnu_matches # => %w{}

def self.multi_match(string, options, split = "_"); end
KLib::GnuMatch.match("s-1", %w{str-1 sym-1 str-2}) # => nil
$gnu_matches # => %w{}
KLib::GnuMatch.match("s-1", %w{str-1 sym-1 str-2}, "-") # => nil
$gnu_matches # => %w{str-1 sym-1 str-2}
KLib::GnuMatch.match("sy-1", %w{str-1 sym-1 str-2}, "-") # => 'sym-1'
```