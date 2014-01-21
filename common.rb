module Common
  def today()
    return Time.now.strftime("%y%m%d")
  end

  def yesterday()
    return (Time.now - (60 * 60 * 24)).strftime("%y%m%d")     # Yesterday's date
  end

  def timestamp()
    return Time.now.strftime("%d%m%y%H%M")
  end

end

class Hash
  def diff(other)
    self.keys.inject({}) do |memo, key|
      unless self[key] == other[key]
        memo[key] = [self[key], other[key]]
      end
      memo
    end
  end
end
