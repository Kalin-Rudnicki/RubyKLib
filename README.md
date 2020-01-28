# RubyKLib
This is an assortment of utilities for Ruby to make doing common and/or tedious tasks easier.  

### Main Attractions
[CLI - Command Line Interface](#cli)  
[ArgumentChecking](#argumentchecking)  
[HashNormalizer](#hashnormalizer)  
[Logger](#logger)  
[CaseConversion / StringCasing](#caseconversion--stringcasing)  

### All
Whole List

### Documentation

#### CLI
Intro  
Basic Usage  
Split / Multi  
#### ArgumentChecking
```ruby
def self.type_check(obj, name *valid_types); end
KLib::ArgumentChecking.type_check(my_int, :my_int, Integer)
KLib::ArgumentChecking.type_check(my_str_or_sym, :my_str_or_sym, String, Symbol)

def self.type_check_each(obj, name, *valid_types)
  type_check(obj, name, Enumerable)
  obj.each_with_index { |e, i| type_check(e, :"#{name}[#{i}]", *valid_types) }
end
KLib::ArgumentChecking.type_check_each(my_strings, :my_strings, String)

def self.enum_check(obj, name, *valid_values); end
KLib::ArgumentChecking.enum_check(my_sym, :my_sym, :first, :last, :all)

def self.enum_check_each(obj, name, *valid_types)
  type_check(obj, name, Enumerable)
  obj.each_with_index { |e, i| enum_check(e, :"#{name}[#{i}]", *valid_types) }
end
KLib::ArgumentChecking.enum_check_each(my_syms, :my_sym, :ex_1, :ex_2, :ex_3, :ex_4)

def self.nil_check(obj, name); end
KLib::ArgumentChecking.nil_check(obj, :obj)

def self.boolean_check(obj, name)
  type_check(obj, name, TrueClass, FalseClass)
end
KLib::ArgumentChecking.boolean_check(bool, :bool)

def self.logger_check(obj, name = :logger)
  type_check(obj, name, KLib::Logger, KLib::DeadObject) # KLib::DeadObject does nothing on any methods
end
KLib::ArgumentChecking.logger_check(logger)

def self.path_check(path, name, type = :any)
  enum_check(type, :type, %i{any file dir exe}
  # ...
end
KLib::ArgumentChecking.path_check(my_path, :my_path)
KLib::ArgumentChecking.path_check(my_path, :my_path, :file)
KLib::ArgumentChecking.path_check(my_path, :my_path, :dir)
KLib::ArgumentChecking.path_check(my_path, :my_path, :exe)
```
#### HashNormalizer
TODO
#### Logger
TODO
#### CaseConversion / StringCasing
TODO
#### ColorString
TODO
#### ArrayUtils
TODO
#### GnuMatch
TODO
#### TraceParse
TODO
