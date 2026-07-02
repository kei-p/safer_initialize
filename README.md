# SaferInitialize

Make ActiveRecord initialization less dangerous.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'safer_initialize'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install safer_initialize

## Usage

In `config/initializers/safer_initialize.rb`:

```ruby
SaferInitialize::Globals.attribute :tenant

SaferInitialize.configure do |config|
  config.error_handle = -> (e) { Rails.env.production? ? Bugsnag.notify(e) : raise(e) } # default: -> (e) { raise e }
end
```

In `app/models/project.rb`:

```ruby
belongs_to :tenant

scope :active, -> { where(deleted_at: nil) }

safer_initialize message: 'Forbidden tenant!' do |project|
  !SaferInitialize::Globals.tenant || SaferInitialize::Globals.tenant == project.tenant
end
safer_initialize :active?, message: 'Not active project!'

def active?
  deleted_at.nil?
end
```

In `app/controllers/application_controller.rb`:

```ruby
before_action :set_tenant

private

def set_tenant
  SaferInitialize::Globals.tenant = current_tenant
end
```

In `app/views/projects/index.html.haml`:

```haml
# raise error
- current_tenant.projects.each do |project|
  = project.name

- Project.active.each do |project|
  = project.name

# good
- current_tenant.projects.active.each do |project|
  = project.name

- SaferInitialize.with_safe do
  - current_tenant.projects.each do |project|
    = project.name
```

## Deferred evaluation (avoiding N+1)

`safer_initialize` runs inside `after_initialize`, which fires while each record
is being built — *before* Rails resolves `includes`/`preload`. If your check
touches an association, it triggers a query per record (N+1), even when the
query eager-loads that association.

Wrap the load in `SaferInitialize.defer` to queue the checks and evaluate them
after the block finishes, once preloading is done:

```ruby
SaferInitialize.defer do
  # Loading through `user.projects` sets the inverse for `project.user`, but not for
  # `project.tenant` — so the tenant check's `project.tenant` needs a query per row.
  # `includes(:tenant)` eager-loads it, but the check runs in `after_initialize` —
  # before the preload resolves — so it still N+1s without `defer`.
  projects = current_user.projects.includes(:tenant).to_a
  # checks are queued here, not evaluated yet
  render_something(projects)
end
# checks run at the block end — the preload is done, so `project.tenant` is cached (no N+1)
```

(`current_tenant.projects` would not N+1 here: loading through that association sets the
inverse, so `project.tenant` is already resolved and `includes(:tenant)` is unnecessary.)

Notes:

- Outside a `defer` block the behavior is unchanged (immediate evaluation).
- Globals (e.g. `tenant`) are expected to stay constant inside the block; set
  them before entering `defer`, not within it. `with_safe` still skips checks
  as usual.
- If the block raises, the queue is discarded without running the checks.
- `defer` cannot be nested.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SaferInitialize project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/aki77/safer_initialize/blob/master/CODE_OF_CONDUCT.md).
