class String
  def camel_case
    self.gsub(/(^|_)(.)/) { $2.upcase }
  end
end  
module Octopi
  class Base
    VALID = {
      :repo => {
        # FIXME: API currently chokes on repository names containing periods,
        # but presumably this will be fixed.
        :pat => /^[A-Za-z0-9_\.-]+$/,
        :msg => "%s is an invalid repository name"},
      :user => {
        :pat => /^[A-Za-z0-9_\.-]+$/,
        :msg => "%s is an invalid username"},
      :file => {
        :pat => /^[^ \/]+$/,
        :msg => "%s is an invalid filename"},
      :sha => {
        :pat => /^[a-f0-9]{40}$/,
        :msg => "%s is an invalid SHA hash"},
      :state => {
        # FIXME: Any way to access Issue::STATES from here?
        :pat => /^(open|closed)$/, 
        :msg => "%s is an invalid state; should be 'open' or 'closed'."  
      }
    }  
    
    attr_accessor :api
    
    def initialize(attributes={})
      # puts "#{self.class.inspect} #{attributes.keys.map { |s| s.to_sym }.inspect}"
      attributes.each do |key, value|
        raise "no attr_accessor set for #{key} on #{self.class}" if !respond_to?(key)
        self.send("#{key}=", value)
      end
    end
    
    def property(p, v)
      path = "#{self.class.path_for(:resource)}/#{p}"
      @api.find(path, self.class.resource_name(:singular), v)
    end
    
    def save
      hash = {}
      @keys.each { |k| hash[k] = send(k) }
      @api.save(self.path_for(:resource), hash)
    end
    
    private
    def self.extract_user_repository(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      if opts.empty?
        if args.length > 1
          repo, user = *args
        else
          repo = args.pop
        end
      else
        opts[:repo] = opts[:repository] if opts[:repository]
        repo = args.pop || opts[:repo]
        user = opts[:user]
      end
      
      user = repo.owner if repo.is_a? Repository
      
      if repo.is_a?(String) and !user
        raise "Need user argument when repository is identified by name"
      end
      ret = extract_names(user, repo)
      ret << opts
      ret
    end

    def self.extract_names(*args)
      args.map do |v|
        v = v.name  if v.is_a? Repository
        v = v.login if v.is_a? User
        v
      end
    end

    def self.validate_args(spec)
      m = caller[0].match(/\/([a-z0-9_]+)\.rb:\d+:in `([a-z_0-9]+)'/)
      meth = m ? "#{m[1].camel_case}.#{m[2]}" : 'method'
      raise ArgumentError, "Invalid spec" unless 
        spec.values.all? { |s| VALID.key? s }
      errors = spec.reject{|arg, spec| arg.nil?}.
                    reject{|arg, spec| arg.to_s.match(VALID[spec][:pat])}.
                    map   {|arg, spec| "Invalid argument '%s' for %s (%s)" % 
                      [arg, meth, VALID[spec][:msg] % arg]} 
      raise ArgumentError, "\n" + errors.join("\n") unless errors.empty?
    end  
  end
end
