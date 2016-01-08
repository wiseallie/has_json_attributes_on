
# Introduction

The has_json_attributes_on plugin allows one to  store attributes in one JSON or JSONB column in the database for
ActiveRecord models and provides validations, typecasting and default values on the accessors.

Similar to ActiveRecord store(store_attribute, options = {})

*Note*: No tests yet. Coming soon....

Example:

```ruby
# == Schema Information
#
# Table name: users
#
#  id              :integer          not null, primary key
#  email           :string
#  profile         :jsonb
#  contact_details :json
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class User < ActiveRecord::Base
  has_json_attributes_on :profile, {
    firstname: {type: 'String', validates: {presence: true, length: {maximum: 20, minimum: 3}}},
    lastname: {type: 'String', validates: {presence: true, length: {maximum: 20}, exclusion: {in: %w(admin ruler)}}},
    age:  {type: 'Integer', default: ->{rand(36)}, validates: {presence: true, numericality: true,  inclusion: { in: 18..35 }}},
    birthday: {type: 'Date', default: ->(u){ u.age.years.ago.to_date}, validates: {presence: true}},
    salary: {type: 'Decimal', validates: {presence: true}},
    married: {type: 'Boolean', default: ->(u){ u.age > 25 ? true : false}},
    kids_names: {type: 'Set'},
    companies: {type: 'Array'},
    extra: {type: 'Hash'}
  }

  has_json_attributes_on :contact_details, {
    google: {}, # default is type is 'String'
    facebook: {type: 'String'},
    twitter: {type: 'String'}
  }
end


User #=> User(id: integer, email: string, profile: jsonb, contact_details: json, created_at: datetime, updated_at: datetime)
u = User.new
=> #<User:0x007fa28542a318
 id: nil,
 email: nil,
 profile: #<User::ProfileDynamicType:0x007fa285429dc8 @age=23, @birthday=Thu, 07 Jan 1993, @companies=[], @extra={}, @firstname=nil, @kids_names=#<Set: {}>, @lastname=nil, @married=false, @salary=nil>,
 contact_details: #<User::ContactDetailsDynamicType:0x007fa28474c060 @facebook=nil, @google=nil, @twitter=nil>,
 created_at: nil,
 updated_at: nil>

u.age       #=> 23
u.profile.age #=> 23

u.age = 30
u.age       #=> 40
u.profile.age #=> 40

u.age = 25
u.age       #=> 25
u.profile.age #=> 25

u.married   #=> false
u.married = 'T'
u.married   #=> true
u.salary    #=> nil
u.salary = '202829.6699'  # Type casted
u.salary    #=> #<BigDecimal:7fa08a618ac8,'0.2028296699E6',18(27)>  #Type casted
```

### Default Values
```ruby
u = User.new(age: 26)
u.age       # => 26
u.married   # => true
u.birthday  # => Sun, 07 Jan 1990
```

### Type casting
```ruby
u.married = 'N'
u.married   #=> false
u.salary = '202829.6699'  # Type casted
u.salary    #=> #<BigDecimal:7fa08a618ac8,'0.2028296699E6',18(27)>  #Type casted
u.kids_names = ['jane', 'jane', 'solly']
u.kids_names #=> #<Set: {"jane", "solly"}>
u.companies = "Apple"
u.companies  #=> ["Apple"]
u.companies = ['Apple', 'Google']
u.companies  #=> ["Apple", "Google"]
u.extra = {x: 3}
u.extra  #=> {:x=>3}
```

### Validations
```ruby
u = User.new()
=> #<User:0x007fa2853e37d8
 id: nil,
 email: nil,
 profile: #<User::ProfileDynamicType:0x007fa2853daea8 @age=31, @birthday=Mon, 07 Jan 1985, @companies=[], @extra={}, @firstname=nil, @kids_names=#<Set: {}>, @lastname=nil, @married=true, @salary=nil>,
 contact_details: #<User::ContactDetailsDynamicType:0x007fa2853b1530 @facebook=nil, @google=nil, @twitter=nil>,
 created_at: nil,
 updated_at: nil>

u.valid?  #=> false
u.errors
=> #<ActiveModel::Errors:0x007fa285313038
 @base=
  #<User:0x007fa2853e37d8
   id: nil,
   email: nil,
   profile: #<User::ProfileDynamicType:0x007fa2853daea8 @age=31, @birthday=Mon, 07 Jan 1985, @companies=[], @extra={}, @firstname=nil, @kids_names=#<Set: {}>, @lastname=nil, @married=true, @salary=nil>,
   contact_details: #<User::ContactDetailsDynamicType:0x007fa2853b1530 @facebook=nil, @google=nil, @twitter=nil>,
   created_at: nil,
   updated_at: nil>,
 @messages={:firstname=>["can't be blank", "is too short (minimum is 3 characters)"], :lastname=>["can't be blank"], :salary=>["can't be blank"]}>

u.attributes = {firstname: 'James', lastname: 'King', salary: '1.6789'}
u.valid?  #=> true
u.save
(2.1ms)  BEGIN
SQL (2.7ms)  INSERT INTO "users" ("profile", "contact_details", "created_at", "updated_at") VALUES ($1, $2, $3, $4) RETURNING "id"  [["profile", "{\"firstname\":\"James\",\"lastname\":\"King\",\"age\":31,\"birthday\":\"1985-01-07\",\"salary\":\"1.6789\",\"married\":true,\"kids_names\":[],\"companies\":[],\"extra\":{}}"], ["contact_details", "{\"google\":null,\"facebook\":null,\"twitter\":null}"], ["created_at", "2016-01-07 08:58:44.945408"], ["updated_at", "2016-01-07 08:58:44.945408"]]
(0.9ms)  COMMIT
=> true

u.salary = '202829.6699'  # Type casted
u.salary    #=> #<BigDecimal:7fa08a618ac8,'0.2028296699E6',18(27)>  #Type casted
u.kids_names = ['jane', 'jane', 'solly']
u.kids_names #=> #<Set: {"jane", "solly"}>
u.companies = "Apple"
u.companies  #=> ["Apple"]
u.companies = ['Apple', 'Google']
u.companies  #=> ["Apple", "Google"]
u.extra = {x: 3}
u.extra  #=> {:x=>3}

u.facebook = "https://facebook.com/someusername"
u.facebook #=> "https://facebook.com/someusername"

u
=> #<User:0x007fa2853e37d8
 id: 2,
 email: nil,
 profile:
  #<User::ProfileDynamicType:0x007fa2853daea8
   @age=31,
   @birthday=Mon, 07 Jan 1985,
   @companies=["Apple", "Google"],
   @extra={:x=>3},
   @firstname="James",
   @kids_names=#<Set: {"jane", "solly"}>,
   @lastname="King",
   @married=true,
   @salary=#<BigDecimal:7fa28ba358b0,'0.2028296699E6',18(27)>>,
 contact_details: #<User::ContactDetailsDynamicType:0x007fa2853b1530 @facebook="https://facebook.com/someusername", @google=nil, @twitter=nil>,
 created_at: Thu, 07 Jan 2016 08:58:44 UTC +00:00,
 updated_at: Thu, 07 Jan 2016 08:58:44 UTC +00:00>

 u.save
   (0.2ms)  BEGIN
  SQL (0.4ms)  UPDATE "users" SET "profile" = $1, "contact_details" = $2, "updated_at" = $3 WHERE "users"."id" = $4  [["profile", "{\"firstname\":\"James\",\"lastname\":\"King\",\"age\":31,\"birthday\":\"1985-01-07\",\"salary\":\"202829.6699\",\"married\":true,\"kids_names\":[\"jane\",\"solly\"],\"companies\":[\"Apple\",\"Google\"],\"extra\":{\"x\":3}}"], ["contact_details", "{\"google\":null,\"facebook\":\"https://facebook.com/someusername\",\"twitter\":null}"], ["updated_at", "2016-01-07 09:07:10.613237"], ["id", 2]]
   (0.2ms)  COMMIT
=> true
```
## Installation

### Rails 4.2.x / Ruby 2.0.0 and higher

The current version of has_json_attributes_on is compatible with Rails 4.2.x and less than 5.0.0, and Ruby 2.0.0 and higher.

Add it to your Gemfile:

```ruby
gem "has_json_attributes_on", "~> 0.0.3"
```

or use the bleeding edge

```ruby
gem "has_json_attributes_on", github: "wiseallie/has_json_attributes_on"
```

### Databases
At the moment this plugin only supports postgres, other databases may be added in later

### What about rails 5

This plugin will be updated for rails 5 soon.

## Credits

This depends on other gems

Virtus: https://github.com/solnic/virtus

default_value_for: https://github.com/FooBarWidget/default_value_for

Thanks to MyTopDog Education for their time. http://mytopdog.co.za
