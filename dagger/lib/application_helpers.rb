module ApplicationHelpers
  def pretty(obj)
    JSON.pretty_generate(obj.as_json) unless obj.nil?
  end
end