module PlusPlus
  module Base
    def plus_plus(*args)
      options = args.extract_options!
      association, column = args

      self.after_create {
        self.plus_plus_on_create_or_destroy association, column, options
      }

      self.after_destroy {
        self.plus_plus_on_create_or_destroy association, column, options
      }
    end

    def plus_plus_on_change(*args)
      options = args.extract_options!
      association, column = args

      self.after_update do
        raise "No :changed option specified" if options[:changed].nil?
        raise "No :plus option specified" if options[:plus].nil?
        raise "No :minus option specified" if options[:minus].nil?
        return unless self.changes.include?(options[:changed])

        warning_about_removal_update_method_from_options(options)

        dup     = self.dup
        changed = options[:changed]
        offset  = if options[:value]
          options[:value].respond_to?(:call) ? self.instance_exec(&options[:value]) : options[:value]
        else
          1
        end

        self.changes.each { |k, v| dup[k] = v.first }  # Create a 'snapshot' of what the model did look like
        prev_satisfied_for_minus = options[:minus].respond_to?(:call) ? dup.instance_exec(&options[:minus]) : dup.send(changed) == options[:minus]
        self_satisfied_for_plus = options[:plus].respond_to?(:call) ? self.instance_exec(&options[:plus]) : self.send(changed) == options[:plus]
        self_satisfied_for_minus = options[:minus].respond_to?(:call) ? self.instance_exec(&options[:minus]) : self.send(changed) == options[:minus]
        prev_satisfied_for_plus = options[:plus].respond_to?(:call) ? dup.instance_exec(&options[:plus]) : dup.send(changed) == options[:plus]

        updated_val = if prev_satisfied_for_minus && self_satisfied_for_plus
          association_model = self.send(association)
          raise "No association #{association}" if association_model.nil?
          association_model.send(column) + offset
        elsif prev_satisfied_for_plus && self_satisfied_for_minus
          association_model = self.send(association)
          raise "No association #{association}" if association_model.nil?
          association_model.send(column) - offset
        else
          nil
        end

        association_model.update_columns(column => updated_val) if updated_val
      end
    end
  end

  module Model
    def warning_about_removal_update_method_from_options(options)
      return unless options[:update_method]

      puts <<-EOQ
      WARNING:
        `:update_method` option was removed from both `plus_plus` and
        `plus_plus_on_change` methods and has no longer effect. Please
        delete the option from your code as well.

        See more details here: https://github.com/Pathgather/plus-plus/pull/1.

        If you depend on the previous behaviour, please update your Gemfile:
        `gem 'plus-plus', github: 'pathgather/plus-plus', ref: '6fd9910'`
      EOQ
    end

    def plus_plus_on_create_or_destroy(association, column, options)
      warning_about_removal_update_method_from_options(options)

      return if options.has_key?(:if) && !self.instance_exec(&options[:if])
      return if options.has_key?(:unless) && self.instance_exec(&options[:unless])
      association_model = self.send(association)
      raise "No association #{association}" unless association_model
      value = if options[:value]
        options[:value].respond_to?(:call) ? self.instance_exec(&options[:value]) : options[:value]
      else
        1
      end
      offset  = self.destroyed? ? -(value) : value
      new_val = association_model.send(column) + offset
      association_model.update_columns(column => new_val)
    end
  end
end
