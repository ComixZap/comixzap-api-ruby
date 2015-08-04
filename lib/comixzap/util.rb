module ComixZap
  module Util
    def natural_sort_array str
      sort_ary = str.downcase.split(/(\d+)/).map {|a| a =~ /\d+/ ? a.to_i : a  }
      sort_ary.fill(0, sort_ary.size...10)
    end

    module_function :natural_sort_array
  end
end
  
