# danger-packwerk

`danger-packwerk` integrates [`packwerk`](https://github.com/Shopify/packwerk) with [`danger`](https://github.com/danger/danger) to provide inline comments in PRs related to boundaries in a Rails application.

## Installation
Step 1: Add this line to your `Gemfile` (to whatever group your CI uses, as it is not needed in production) and `bundle install`:

```ruby
gem 'danger-packwerk', group: :test
```

Step 2: Add these to your `Dangerfile`:

```ruby
packwerk.check
deprecated_references_yml_changes.check
```

That's it for basic usage!

## Usage

There are currently two danger checks that ship with `danger-packwerk`:
1) One that runs `bin/packwerk check` and leaves inline comments in source code on new violations
2) One that looks at changes to `deprecated_references.yml` files and leaves inline comments on added violations.

In upcoming iterations, we will include other danger checks, including:
1) A danger check that detects changes to `package.yml` files and posts user-configurable messages on the `package.yml` files that are modified.
2) A danger check that detects changes to `packwerk.yml` files and allows you to specify the action taken when that happens.

## packwerk.check
![This is an image displaying a comment from the Danger github bot. The comment is inline with the PR in Github and displays the following text. Dependency violation: ::FeatureFlag belongs to 'packs/feature_flags', but 'packs/gusto_slack' does not specify a dependency on 'packs/feature_flags'. Are we missing an abstraction? Is the code making the reference, and the referenced constant, in the right packages? Inference details: this is a reference to ::FeatureFlag which seems to be defined in packs/feature_flags/app/models/feature_flag.rb. To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations Privacy violation: '::FeatureFlag' is private to 'packs/feature_flags' but referenced from 'packs/gusto_slack'. Is there a public entrypoint in 'packs/feature_flags/app/public/' that you can use instead? Inference details: this is a reference to ::FeatureFlag which seems to be defined in packs/feature_flags/app/models/feature_flag.rb. To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations](docs/basic_usage.png)

Without any configuration, `packwerk.check` should just work. By default, it will post a maximum of 15 messages in a PR, using the default messaging from packwerk, and it will not fail the build.

`packwerk.check` can be configured to in the following ways:

### Change the message that displays in the markdown
The default message displayed is from `bin/packwerk check`. To customize this this, pass in `offenses_formatter` to `packwerk.check` in your `Dangerfile`. Here's a simple example:
```ruby
packwerk.check(
  # Offenses are a T::Array[Packwerk::ReferenceOffense] => https://github.com/Shopify/packwerk/blob/main/lib/packwerk/reference_offense.rb
  offenses_formatter: -> (offenses) do
    "There are #{offenses.count} packwerk offenses on this line!"
  end
)
```

A more advanced example could give more specific information about the violation and information specific to your organization or project about how to resolve. Here is a screenshot of what our message looks like at Gusto:
![This is an image displaying a comment from the Danger github bot. The comment is inline with the PR in Github and displays the following text: Hi there! It looks like FeatureFlag is private API of packs/feature_flags, which is also not in packs/gusto_slack's list of dependencies. Before you run bin/packwerk update-deprecations, read through How to Handle Dependency and Privacy Violations (with Flow Chart!). Here are some quick suggestions to resolve: Does the code you are writing live in the right pack? If not, try bin/move_to_pack -n packs/destination_pack -f packs/gusto_slack/app/services/slack/client.rb. Does FeatureFlag live in the right pack? If not, try bin/move_to_pack -n packs/destination_pack -f packs/feature_flags/app/models/feature_flag.rb. Do we actually want to depend on packs/feature_flags. If so, try adding packs/feature_flags to packs/gusto_slack/package.yml dependencies. If not, what can we change about the design so we do not have to depend on packs/feature_flags? Does API in packs/feature_flags/public support this use case? If not, can we work with @Gusto/product-infrastructure to create and use a public API? If FeatureFlag should already be public, try bin/make_public -f packs/feature_flags/app/models/feature_flag.rb. Need help? Join us in #ruby-modularity or provide feedback.](docs/advanced_usage.png)

### Fail the build on new violations
Simply pass in `fail_build: true` into `check`, as such:
```ruby
packwerk.check(fail_build: true)
```

If you want to change the default error message, which is `Packwerk violations were detected! Please resolve them to unblock the build.`, then you can also pass in `failure_message`.

### Change the max number of comments that will display
If you do not change this, the default max is 15. More information about why we chose this number in the source code.
```ruby
packwerk.check(max_comments: 3)
```

### Do something extra when there are packwerk failures
Maybe you want to notify slack or do something else when there are packwerk failures.

```ruby
packwerk.check(
  # Offenses are a T::Array[Packwerk::ReferenceOffense] => https://github.com/Shopify/packwerk/blob/main/lib/packwerk/reference_offense.rb
  on_failure: -> (offenses) do
    # Notify slack or otherwise do something extra!
  end
)
```

## deprecated_references_yml_changes.check
![This is an image displaying a comment from the Danger github bot. The comment is inline with the PR in Github and displays the following text. We noticed you ran `bin/packwerk update-deprecations`. Make sure to read through the docs for other ways to resolve.](docs/basic_usage_2.png)

Without any configuration, `deprecated_references_yml_changes.check` should just work. By default, it will post a maximum of 15 messages in a PR, using default messaging defined within this gem.

`deprecated_references_yml_changes.check` can be configured to in the following ways:

### Change the message that displays in the markdown
The default message displayed is from `lib/danger-packwerk/private/default_offenses_formatter.rb`. To customize this this, pass in `offenses_formatter` to `deprecated_references_yml_changes.check` in your `Dangerfile`. Here's a simple example:
```ruby
deprecated_references_yml_changes.check(
  # Offenses are a T::Array[DangerPackwerk::BasicReferenceOffense]
  offenses_formatter: -> (added_offenses) do
    "There are #{added_offenses.count} new violations this line!"
  end
)
```

A more advanced example could give more specific information about the violation and information specific to your organization or project about how to resolve. Here is a screenshot of what our message looks like at Gusto:
![This is an image displaying a comment from the Danger github bot. The comment is inline with the PR in Github and displays the following text. Hi again! It looks like FeatureFlag is private API of packs/feature_flags, which is also not in packs/gusto_slack's list of dependencies.. We noticed you ran bin/packwerk update-deprecations. Make sure to read through How to Handle Dependency and Privacy Violations (with Flow Chart!). Could you add some context as a reply here about why we needed to add these violations packs/gusto_slack/package.yml is configured with notify_on_new_violations to notify @Gusto/product-infrastructure (#product-infrastructure) on new dependency violations. packs/feature_flags/package.yml is configured with notify_on_new_violations to notify @Gusto/product-infrastructure (#product-infrastructure) on new privacy violations
Need help? Join us in #ruby-modularity or provide feedback.
](docs/advanced_usage_2.png)

### Change the max number of comments that will display
If you do not change this, the default max is 15. More information about why we chose this number in the source code.
```ruby
deprecated_references_yml_changes.check(max_comments: 3)
```

### Do something extra before we leave comments
Maybe you want to notify slack or do something else before we leave comments.

```ruby
deprecated_references_yml_changes.check(
  # violation_diff is a DangerPackwerk::ViolationDiff and changed_deprecated_references_ymls is a T::Array[String]
  before_comment: -> (violation_diff, changed_deprecated_references_ymls) do
    # Notify slack or otherwise do something extra!
  end
)
```

## Development

We welcome your contributions! Please create an issue or pull request and we'd be happy to take a look.
