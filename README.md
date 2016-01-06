
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
#  contact_details :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class User < ActiveRecord::Base
  has_json_attributes_on :profile, {
    firstname: {type: 'String', validates: {presence: true, length: {maximum: 20, minimum: 3}},
    lastname: {type: 'String', validates: {presence: true, length: {maximum: 20}, exclusion: {in: %w(admin ruler)}}},
    age:  {type: 'Integer', default: 20, validates: {presence: true, numericality: true,  inclusion: { in: 18..35 }}},
    birthday: {type: 'Date', default: -> {10.year.ago }, validates: {presence: true},
    salary: {type: 'Decimal', validates: {presence: true}},
    married: {type: 'Boolean', default: -> { age > 30 ? true : false},
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
=> #<User:0x007fa088d5d8d0
 id: nil,
 email: nil,
 profile: #<User::ProfileDynamicType:0x007fa088ced7b0 @age=20, @birthday=Tue, 01 Jan 1985, @companies=[], @extra={}, @firstname=nil, @kids_names=#<Set: {}>, @lastname=nil, @married=true, @salary=nil>,
 contact_details: #<User::ContactDetailsDynamicType:0x007fa088cac648 @facebook=nil, @google=nil, @twitter=nil>,
 created_at: nil,
 updated_at: nil>

u.age       # => 20
u.married   # => true
u.married = 'N'
u.married   #=> false
u.salary    #=> nil
u.salary = '202829.6699'  # Typecasted
u.salary    #=> #<BigDecimal:7fa08a618ac8,'0.2028296699E6',18(27)>  #Typecasted
```

### Default Values
```ruby
u.age       # => 20
u.married   # => true
u.birthday  # => Tue, 01 Jan 1985
```

### Type casting
```ruby
u.married = 'N'
u.married   #=> false
u.salary = '202829.6699'  # Typecasted
u.salary    #=> #<BigDecimal:7fa08a618ac8,'0.2028296699E6',18(27)>  #Typecasted
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
u.valid?  #=> false
u.errors
=> #<ActiveModel::Errors:0x007fa08c002ad8
 @base=
  #<User:0x007fa088d5d8d0
   id: nil,
   email: nil,
   profile: #<User::ProfileDynamicType:0x007fa088ced7b0 @age=20, @birthday=Tue, 01 Jan 1985, @companies=[], @extra={}, @firstname=nil, @kids_names=#<Set: {}>, @lastname=nil, @married=true, @salary=nil>,
   contact_details: #<User::ContactDetailsDynamicType:0x007fa088cac648 @facebook=nil, @google=nil, @twitter=nil>,
   created_at: nil,
   updated_at: nil>,
 @messages={:firstname=>["can't be blank", "is too short (minimum is 3 characters)"], :lastname=>["can't be blank"], :salary=>["can't be blank"]}>

u.attributes = {firstname: 'James', lastname: 'King', salary: '1.6789'}
u.valid?  #=> true
u.save
   (0.2ms)  BEGIN
  SQL (3.3ms)  INSERT INTO "users" ("profile", "contact_details", "created_at", "updated_at") VALUES ($1, $2, $3, $4) RETURNING "id"  [["profile", "{\"firstname\":\"James\",\"lastname\":\"King\",\"age\":20,\"birthday\":\"1985-01-01\",\"salary\":\"1.6789\",\"married\":true,\"kids_names\":[\"jane\",\"solly\"],\"companies\":[\"Apple\",\"Google\"],\"extra\":{\"x\":3}}"], ["contact_details", "{\"google\":null,\"facebook\":null,\"twitter\":null}"], ["created_at", "2016-01-06 14:30:10.610800"], ["updated_at", "2016-01-06 14:30:10.610800"]]
   (0.3ms)  COMMIT
=> true

```
## Installation

### Rails 4.2.x / Ruby 2.0.0 and higher

The current version of has_json_attributes_on is compatible with Rails 4.2.x and less than 5.0.0, and Ruby 2.0.0 and higher.

Add it to your Gemfile:

```ruby
gem "has_json_attributes_on", "~> 1.0.0", github: "wiseallie/has_json_attributes_on"
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
