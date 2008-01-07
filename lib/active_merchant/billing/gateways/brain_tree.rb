require File.join(File.dirname(__FILE__), '..', 'check.rb')

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BrainTreeGateway < Gateway
      URL = 'https://secure.braintreepaymentgateway.com/api/transact.php'
    
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.braintreepaymentsolutions.com'
      self.display_name = 'Braintree'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, creditcard,options)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('auth', money, post)
      end
      
      def purchase(money, payment_source, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, payment_source, options)        
        add_address(post, payment_source, options)   
        add_customer_data(post, options)
             
        commit('sale', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post ={}
        post[:transactionid] = authorization
        commit('capture', money, post)
      end
    
      private                             
      def add_customer_data(post, options)
        if options.has_key? :email
          post[:email] = options[:email]
        end

        if options.has_key? :ip
          post[:ipaddress] = options[:ip]
        end        
      end

      def add_address(post, creditcard, options)     
        if address = options[:billing_address] || options[:address]
          post[:address1]    = address[:address1].to_s
          post[:address2]    = address[:address2].to_s unless address[:address2].blank?
          post[:company]    = address[:company].to_s
          post[:phone]      = address[:phone].to_s
          post[:zip]        = address[:zip].to_s       
          post[:city]       = address[:city].to_s
          post[:country]    = address[:country].to_s
          post[:state]      = address[:state].blank?  ? 'n/a' : address[:state]
        end         
      end

      def add_invoice(post, options)
        post[:orderid] = options[:order_id].to_s.gsub(/[^\w.]/, '')
      end
      
      def add_payment_source(params, source, options={})
        case determine_funding_source(source)
        when :vault       then add_customer_vault_id(params, source)
        when :credit_card then add_creditcard(params, source, options)
        when :check       then add_check(params, source)
        end
      end
      
      def add_customer_vault_id(params,vault_id)
        params[:customer_vault_id] = vault_id
      end
      
      def add_creditcard(post, creditcard,options)   
        post[:customer_vault] = "add_customer" if options[:store]
        
        post[:ccnumber]  = creditcard.number
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
        post[:ccexp]  = expdate(creditcard)
        post[:firstname] = creditcard.first_name
        post[:lastname]  = creditcard.last_name   
      end
      
      def add_check(post, check)
        post[:payment] = 'check' # Set transaction to ACH
        post[:checkname] = check.name # The name on the customer's Checking Account
        post[:checkaba] = check.routing_number # The customer's bank routing number
        post[:checkaccount] = check.account_number # The customer's account number
        post[:account_holder_type] = check.account_holder_type # The customer's type of ACH account
        post[:account_type] = check.account_type # The customer's type of ACH account
      end
      
      def parse(body)
        results = {}
        body.split(/&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end
        
        results
      end     
      
      def commit(action, money, parameters)
        parameters[:amount]  = amount(money) if money
        
        data = ssl_post URL, post_data(action,parameters)
        @response = parse(data)

        Response.new(@response["response"] == "1", message_from(@response), @response, 
          :authorization => @response["transactionid"],
          :test => test?,
          :cvv_code => @response["cvvresponse"],
          :avs_code => @response["avsresponse"],
          :card_number => parameters[:ccnumber]
        )
        
      end
      
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
      

      def message_from(response)
        case response["responsetext"]
        when "SUCCESS","Approved"
          "This transaction has been approved"
        when "DECLINE"
          "This transaction has been declined"
        else
          response["responsetext"]
        end
      end
      
      def post_data(action, parameters = {})
        post = {}
        post[:username]      = @options[:login]
        post[:password]   = @options[:password]
        post[:type]       = action

        request = post.merge(parameters).map {|key,value| "#{key}=#{CGI.escape(value.to_s)}"}.join("&")
        request        
      end
      
      def determine_funding_source(source)
        case 
        when source.is_a?(String) then :vault
        when CreditCard.card_companies.keys.include?(source.type) then :credit_card
        when source.type == 'check' then :check
        else raise ArgumentError, "Unsupported funding source provided"
        end
      end
    end
  end
end

