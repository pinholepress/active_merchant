require 'test_helper'

class RemotePayflowTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = PayflowGateway.new(fixtures(:payflow))

    @credit_card = credit_card(
      '5105105105105100',
      brand: 'master'
    )

    @options = {
      billing_address: address,
      email: 'cody@example.com',
      customer: 'codyexample'
    }

    @extra_options = {
      order_id: '123',
      description: 'Description string',
      order_desc: 'OrderDesc string',
      comment: 'Comment string',
      comment2: 'Comment2 string',
      merch_descr: 'MerchDescr string'
    }

    @check = check(
      routing_number: '111111118',
      account_number: '1111111111'
    )

    @l2_json = '{
        "Tender": {
          "ACH": {
            "AcctType": "C",
            "AcctNum": "6355059797",
            "ABA": "021000021"
          }
        }
      }'

    @l3_json = '{
        "Invoice": {
          "Date": "20190104",
          "Level3Invoice": {
            "CountyTax": {"Amount": "3.23"}
          },
          "Items":
            "<Item Number=\"1\"><SKU>1111</SKU><UPC>9999</UPC><Description>Widget</Description><Quantity>2</Quantity><UnitOfMeasurement>INQ</UnitOfMeasurement><UnitPrice>49.99</UnitPrice><DiscountAmt>9.98</DiscountAmt><FreightAmt>3.00</FreightAmt><HandlingAmt>8.00</HandlingAmt><TotalAmt>101.00</TotalAmt><PickUp>  <Address>  <Street>500 Main St.</Street><City>Anytown</City><State>NY</State><Zip>67890</Zip><Country>US</Country></Address><Time>15:30</Time><Date>20030630</Date><RecordNumber>24680</RecordNumber></PickUp><TrackingNumber>ABC0123</TrackingNumber><Delivery><Date>20030714</Date><Time>12:00</Time></Delivery><UNSPSCCode>54.10.15.05</UNSPSCCode></Item><Item Number=\"2\"><SKU>2222</SKU><UPC>8888</UPC><Description>Gizmo</Description><Quantity>5</Quantity><UnitOfMeasurement>INQ</UnitOfMeasurement><UnitPrice>9.99</UnitPrice><DiscountAmt>2.50</DiscountAmt><FreightAmt>3.00</FreightAmt><HandlingAmt>2.50</HandlingAmt><TotalAmt>52.95</TotalAmt><PickUp>  <Address>    <Street>500 Main St.</Street><City>Anytown</City><State>NY</State><Zip>67890</Zip><Country>US</Country></Address><Time>09:00</Time><Date>20030628</Date><RecordNumber>13579</RecordNumber></PickUp><TrackingNumber>XYZ7890</TrackingNumber><Delivery><Date>20030711</Date><Time>09:00</Time></Delivery><UNSPSCCode>54.10.16.05</UNSPSCCode></Item>"
        }
      }'
  end

  def test_successful_purchase
    assert response = @gateway.purchase(100000, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
    assert !response.fraud_review?
  end

  def test_successful_purchase_with_stored_credential
    @options[:stored_credential] = {
      initial_transaction: true,
      reason_type: 'recurring',
      initiator: 'cardholder',
      network_transaction_id: nil
    }
    assert response = @gateway.purchase(100000, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response

    @options[:stored_credential] = {
      initial_transaction: false,
      reason_type: 'recurring',
      initiator: 'merchant',
      network_transaction_id: response.authorization
    }
    assert response = @gateway.purchase(100000, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
  end

  def test_successful_purchase_with_extra_options
    assert response = @gateway.purchase(100000, @credit_card, @options.merge(@extra_options))
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
    assert !response.fraud_review?
  end

  def test_successful_purchase_with_application_id
    ActiveMerchant::Billing::PayflowGateway.application_id = 'partner_id'

    assert response = @gateway.purchase(100000, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
    assert !response.fraud_review?
  ensure
    ActiveMerchant::Billing::PayflowGateway.application_id = nil
  end

  # In order for this remote test to pass, you must go into your Payflow test
  # backend and enable the correct filter. Once logged in:
  # "Service Settings" ->
  #   "Fraud Protection" ->
  #     "Test Setup" ->
  #       "Edit Standard Filters" ->
  #         Check "BIN Risk List Match" filter *only*, set to "Review" ->
  #           "Deploy" ->
  #             WAIT AT LEAST AN HOUR. FOR REALZ.
  def test_successful_purchase_with_fraud_review
    assert response = @gateway.purchase(
      100000,
      credit_card('5555555555554444', verification_value: '')
    )
    assert_success response, 'This is probably failing due to your Payflow test account not being set up for fraud filters.'
    assert_equal '126', response.params['result']
    assert response.fraud_review?
  end

  def test_successful_purchase_with_l2_fields
    options = @options.merge(level_two_fields: @l2_json)

    assert response = @gateway.purchase(100000, @credit_card, options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_successful_purchase_with_l3_fields
    options = @options.merge(level_three_fields: @l3_json)

    assert response = @gateway.purchase(100000, @credit_card, options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_successful_purchase_with_l2_l3_fields
    options = @options.merge(level_two_fields: @l2_json).merge(level_three_fields: @l3_json)

    assert response = @gateway.purchase(100000, @credit_card, options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_successful_purchase_with_l3_fields_and_application_id
    ActiveMerchant::Billing::PayflowGateway.application_id = 'partner_id'

    options = @options.merge(level_three_fields: @l3_json)

    assert response = @gateway.purchase(100000, @credit_card, options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  ensure
    ActiveMerchant::Billing::PayflowGateway.application_id = nil
  end

  def test_declined_purchase
    assert response = @gateway.purchase(210000, @credit_card, @options)
    assert_equal 'Declined', response.message
    assert_failure response
    assert response.test?
  end

  # Additional steps are required to enable ACH in a Payflow Pro account.
  # See the "Payflow ACH Payment Service Guide" for more details:
  #     http://www.paypalobjects.com/webstatic/en_US/developer/docs/pdf/pp_achpayment_guide.pdf
  #
  # Also, when testing against the pilot-payflowpro.paypal.com endpoint, ACH must be enabled by Payflow support.
  # This can be accomplished by sending an email to payflow-support@paypal.com with your Merchant Login.
  def test_successful_ach_purchase
    assert response = @gateway.purchase(50, @check)
    assert_success response, 'This is probably failing due to your Payflow test account not being set up for ACH.'
    assert_equal 'Approved', response.message
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_ach_purchase_and_refund
    assert response = @gateway.purchase(50, @check)
    assert_success response
    assert_equal 'Approved', response.message
    assert !response.authorization.blank?

    assert credit = @gateway.refund(50, response.authorization)
    assert_success credit
  end

  def test_successful_authorization
    assert response = @gateway.authorize(100, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(100, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(100, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_capture_with_three_d_secure_option
    assert auth = @gateway.authorize(100, @credit_card, @options.merge(three_d_secure_option))
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(100, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_with_application_id
    ActiveMerchant::Billing::PayflowGateway.application_id = 'partner_id'

    assert response = @gateway.authorize(100000, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
    assert !response.fraud_review?
  ensure
    ActiveMerchant::Billing::PayflowGateway.application_id = nil
  end

  def test_authorize_and_partial_capture
    assert auth = @gateway.authorize(100 * 2, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(100, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_complete_capture
    assert auth = @gateway.authorize(100 * 2, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(100, auth.authorization, capture_complete: 'Y')
    assert_success capture

    assert capture = @gateway.capture(100, auth.authorization)
    assert_failure capture
  end

  def test_authorize_and_uncomplete_capture
    assert auth = @gateway.authorize(100 * 2, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(100, auth.authorization, capture_complete: 'N')
    assert_success capture

    assert capture = @gateway.capture(100, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(100, '999')
    assert_failure response
    assert_equal 'Invalid tender', response.message
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(100, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Verified', response.message
  end

  def test_successful_verify_amex
    @amex_credit_card = credit_card(
      '378282246310005',
      brand: 'american_express'
    )
    assert response = @gateway.verify(@amex_credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_verify
    assert response = @gateway.verify(credit_card('4000056655665556'), @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_invalid_login
    gateway = PayflowGateway.new(
      login: '',
      password: ''
    )
    assert response = gateway.purchase(100, @credit_card, @options)
    assert_equal 'Invalid vendor account', response.message
    assert_failure response
  end

  def test_duplicate_request_id
    request_id = SecureRandom.hex(16)
    SecureRandom.expects(:hex).times(2).returns(request_id)

    response1 = @gateway.purchase(100, @credit_card, @options)
    assert response1.success?
    assert_nil response1.params['duplicate']

    response2 = @gateway.purchase(100, @credit_card, @options)
    assert response2.success?
    assert response2.params['duplicate'], response2.inspect
  end

  def test_create_recurring_profile
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(1000, @credit_card, periodicity: :monthly)
    end
    assert_success response
    assert !response.params['profile_id'].blank?
    assert response.test?
  end

  def test_create_recurring_profile_with_invalid_date
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(1000, @credit_card, periodicity: :monthly, starting_at: Time.now)
    end
    assert_failure response
    assert_equal 'Field format error: Start or next payment date must be a valid future date', response.message
    assert response.params['profile_id'].blank?
    assert response.test?
  end

  def test_create_and_cancel_recurring_profile
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(1000, @credit_card, periodicity: :monthly)
    end
    assert_success response
    assert !response.params['profile_id'].blank?
    assert response.test?

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.cancel_recurring(response.params['profile_id'])
    end
    assert_success response
    assert response.test?
  end

  def test_full_feature_set_for_recurring_profiles
    # Test add
    @options.update(
      periodicity: :weekly,
      payments: '12',
      starting_at: Time.now + 1.day,
      comment: 'Test Profile'
    )
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(100, @credit_card, @options)
    end
    assert_equal 'Approved', response.params['message']
    assert_equal '0', response.params['result']
    assert_success response
    assert response.test?
    assert !response.params['profile_id'].blank?
    @recurring_profile_id = response.params['profile_id']

    # Test modify
    @options.update(
      periodicity: :monthly,
      starting_at: Time.now + 1.day,
      payments: '4',
      profile_id: @recurring_profile_id
    )
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(400, @credit_card, @options)
    end
    assert_equal 'Approved', response.params['message']
    assert_equal '0', response.params['result']
    assert_success response
    assert response.test?

    # Test inquiry
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring_inquiry(@recurring_profile_id)
    end
    assert_equal '0', response.params['result']
    assert_success response
    assert response.test?

    # Test payment history inquiry
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring_inquiry(@recurring_profile_id, history: true)
    end
    assert_equal '0', response.params['result']
    assert_success response
    assert response.test?

    # Test cancel
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.cancel_recurring(@recurring_profile_id)
    end
    assert_equal 'Approved', response.params['message']
    assert_equal '0', response.params['result']
    assert_success response
    assert response.test?
  end

  # Note that this test will only work if you enable reference transactions!!
  def test_reference_purchase
    assert response = @gateway.purchase(10000, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
    assert_not_nil pn_ref = response.authorization

    # now another purchase, by reference
    assert response = @gateway.purchase(10000, pn_ref)
    assert_equal 'Approved', response.message
    assert_success response
    assert response.test?
  end

  def test_recurring_with_initial_authorization
    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(1000, @credit_card,
        periodicity: :monthly,
        initial_transaction: {
          type: :purchase,
          amount: 500
        })
    end

    assert_success response
    assert !response.params['profile_id'].blank?
    assert response.test?
  end

  def test_purchase_and_refund
    amount = 100

    assert purchase = @gateway.purchase(amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
    assert !purchase.authorization.blank?

    assert credit = @gateway.refund(amount, purchase.authorization)
    assert_success credit
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = PayflowGateway.new(login: 'unknown_login', password: 'unknown_password', partner: 'PayPal')
    assert !gateway.verify_credentials
  end

  def test_purchase_and_refund_with_three_d_secure_option
    amount = 100

    assert purchase = @gateway.purchase(amount, @credit_card, @options.merge(three_d_secure_option))
    assert_success purchase
    assert_equal 'Approved', purchase.message
    assert !purchase.authorization.blank?

    assert credit = @gateway.refund(amount, purchase.authorization)
    assert_success credit
  end

  # The default security setting for Payflow Pro accounts is Allow
  # non-referenced credits = No.
  #
  # Non-referenced credits will fail with Result code 117 (failed the security
  # check) unless Allow non-referenced credits = Yes in PayPal manager
  def test_purchase_and_credit
    assert credit = @gateway.credit(100, @credit_card, @options)
    assert_success credit, 'This is probably failing due to your Payflow test account not being set up to allow non-referenced credits.'
  end

  def test_successful_ach_credit
    assert response = @gateway.credit(50, @check)
    assert_success response, 'This is probably failing due to your Payflow test account not being set up for ACH.'
    assert_equal 'Approved', response.message
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_high_verbosity
    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_nil response.params['transaction_time']
    @gateway.options[:verbosity] = 'HIGH'
    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_match %r{^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}}, response.params['transaction_time']
  end

  def three_d_secure_option
    {
      three_d_secure: {
        authentication_id: 'QvDbSAxSiaQs241899E0',
        authentication_response_status: 'Y',
        eci: '02',
        cavv: 'jGvQIvG/5UhjAREALGYa6Vu/hto=',
        xid: 'UXZEYlNBeFNpYVFzMjQxODk5RTA='
      }
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)

    transcript = capture_transcript(@gateway) do
      @gateway.purchase(50, @check)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
