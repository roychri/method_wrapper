# Allows you to wrap every class method of your class around some code that
# can be run before and/or after every single class methods.
#
# ==== Example
#
#   class MyClass
#
#     include MethodWrapper
#     before_method :i_am_first
#     after_method  :i_am_last
#
#     def self.i_am_first
#       puts "Who are you?"
#     end
#     def self.i_am_last
#       puts "Nice to meet you!"
#     end
#
#     def foo
#       puts "I am Foo"
#     end
#     def bar
#       puts "I am Bar"
#     end
#
#   end
#
#   MyClass.foo   # => Who are you?\nI am Foo\nNice to meet you!
#   MyClass.bar   # => Who are you?\nI am Bar\nNice to meet you!
module MethodWrapper

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    # List of methods to call before every methods.
    @@before_methods  = []
    # List of methods to call after every methods.
    @@after_methods   = []

    # Do not wrap these methods.
    # This includes the methods that belong to Object and the methods defined in here.
    @@wrap_exclusions = [
                         :singleton_method_added,
                         :time_to_call_after_methods?,
                         :time_to_call_before_methods?,
                         :entering_wrap_method,
                         :leaving_wrap_method,
                         :before_method,
                         :before_methods,
                         :after_method,
                         :after_methods
                        ].
      concat(Object.methods)

    # Used to: Do not call the before methods unless the after method was called.
    # Do not call the after method more than once
    @@inside_methods = 0

    # This is a hook method that ruby will call whenever a method is added.
    def singleton_method_added(singleton_method_name)

      # Skip any methods that are excluded.  See @@wrap_exclusions for more information.
      if @@wrap_exclusions.include?(singleton_method_name.to_sym)
        return
      end

      # A method that was once wrapped must now be in the excluded list, as well as it's alias.
      # This is to prevent infinite loop.
      @@wrap_exclusions << singleton_method_name.to_sym
      @@wrap_exclusions << "old_#{singleton_method_name}".to_sym

      # Because I am in a class method here, I need the special self.class_eval
      # in order to add new class methods.  Because the names are part of a variable,
      # I use the HEREDOC so I can call alias_method and redefine the same method.
      #
      # * We create an alias so we can call the original method.
      # * We redefine the method by calling before and after callbacks.
      # * The before callbacks are skipped if they are already called without the after.
      # * The after callbacks are skipped if one of the method called a sibbling.
      #   We only do the after callbacks when its the original methods that has finished.
      # * Any arguments and return values are perseved
      # * Methods that supports blocks are not supported.
      self.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        class << self
          alias_method :old_#{singleton_method_name}, :#{singleton_method_name}
        end
        def self.#{singleton_method_name}(*args)
          if time_to_call_before_methods?
            before_methods.each do |method|
              send(method)
            end
          end
          entering_wrap_method
          result = old_#{singleton_method_name} *args
          leaving_wrap_method
          if time_to_call_after_methods?
            after_methods.each do |method|
              send(method)
            end
          end
          result
        end
      RUBY_EVAL

    end

    # Indicate a method to call before every wrapped method.
    def before_method(method)
      @@before_methods << method
      @@wrap_exclusions << method.to_sym # This method will not be wrapped.
    end

    # Indicate a method to call after every wrapped method.
    def after_method(method)
      @@after_methods << method
      @@wrap_exclusions << method.to_sym # This method will not be wrapped.
    end

    protected

    # Indicate if its time to call the +after+ callbacks.
    # It is only allowed when its the original method that was called
    # that has finished. When one of the wrapped method called another
    # wrapped method, it will not call after callbacks only after the
    # original method is finished, not when the second method is called
    # from within the original.
    def time_to_call_after_methods?
      @@inside_methods == 0
    end

    # Indicate if its time to call the +before+ callbacks.
    # It is only allowed when no other wrapped methods has been called
    # and is still running.  This is to prevent the before method to
    # be called more than once and ont wrapped method calls another.
    def time_to_call_before_methods?
      @@inside_methods == 0
    end

    # Indicate that a wrapped method is being called.
    def entering_wrap_method
      @@inside_methods += 1
    end

    # Indicate we are leaving the wrapped method.
    def leaving_wrap_method
      @@inside_methods -= 1
    end

    # Returns the list of the methods to call before the wrapped methods.
    def before_methods
      @@before_methods
    end

    # Returns the list of the methods to call after the wrapped methods.
    def after_methods
      @@after_methods
    end

  end
end
