module PlusPlus
  module Base
    def plus_plus(association, options={})
      self.after_create {
        self.plus_plus_on_create_or_destroy(association, options)
      }

      self.after_destroy {
        self.plus_plus_on_create_or_destroy(association, options)
      }
    end

    def plus_plus_on_change(association, options = {})
      self.after_update do
        association_model = self.send(association)
        raise "No association #{association}" if association_model.nil?
        raise "No :column option specified" if options[:column].nil?
        raise "No :changed option specified" if options[:changed].nil?
        raise "No :plus option specified" if options[:plus].nil?
        raise "No :minus option specified" if options[:minus].nil?
        return unless self.changes.include?(options[:changed])

        dup     = self.dup
        changed = options[:changed]
        column  = options[:column]
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
          association_model.send(column) + offset
        elsif prev_satisfied_for_plus && self_satisfied_for_minus
          association_model.send(column) - offset
        else
          nil
        end

        association_model.send options[:update_method] || :update_columns, {column => updated_val} if updated_val
      end
    end
  end

  module Model
    def plus_plus_on_create_or_destroy(association, options)
      association_model = self.send(association)
      raise "No association #{association}" unless association_model
      raise "No column specified" unless options[:column]
      return if options.has_key?(:if) && !self.instance_exec(&options[:if])
      return if options.has_key?(:unless) && self.instance_exec(&options[:unless])
      value = if options[:value]
        options[:value].respond_to?(:call) ? self.instance_exec(&options[:value]) : options[:value]
      else
        1
      end
      column  = options[:column]
      offset  = self.destroyed? ? -(value) : value
      new_val = association_model.send(column) + offset
      association_model.send options[:update_method] || :update_columns, {column => new_val}
    end
  end
end