# Remote Development Rails domain developer documentation: `ee/lib/remote_development` overview

## Table of Contents

- [TL;DR and Quickstart](#tldr-and-quickstart)
- [Overview](#overview)
  - [Layered architecture](#layered-architecture)
  - [Avoid coupling Domain Logic layer to Rails application](#avoid-coupling-domain-logic-layer-to-rails-application)
- [Type safety](#type-safety)
    - [Type checking](#type-checking)
    - [Union types](#union-types)
    - [Pattern matching with types](#pattern-matching-with-types)
    - [Null safety](#null-safety)
    - ["Type signatures" in Ruby without a type system](#type-signatures-in-ruby-without-a-type-system)
- [Functional patterns](#functional-patterns)
    - [Immutable state](#immutable-state)
    - [Higher order functions](#higher-order-functions)
    - [Pure functions](#pure-functions)
    - [Concurrency and parallelism](#concurrency-and-parallelism)
    - [Error Handling](#error-handling)
- [Object-Oriented patterns](#object-oriented-patterns)
    - [Value Objects](#value-objects)
    - [Mixins/Inheritance](#mixinsinheritance)
- [Other patterns](#other-patterns)
    - [Inversion of Control](#inversion-of-control)
    - [Metaprogramming](#metaprogramming)
- [Railway Oriented Programming and the Result Class](#railway-oriented-programming-and-the-result-class)
    - [Result class](#result-class)
    - [Message class and Messages module](#message-class-and-messages-module)
    - [ROP code examples](#rop-code-examples)
    - [Passing information along the ROP chain](#passing-information-along-the-rop-chain)
- [Benefits](#benefits)
- [Differences from standard GitLab patterns](#differences-from-standard-gitlab-patterns)
- [Remote Development Settings](#remote-development-settings)
  - [Overview of Remote Development Settings module](#overview-of-remote-development-settings-module)
  - [Adding a new setting](#adding-a-new-setting)
  - [Reading settings](#reading-settings)
  - [Precedence of settings](#precedence-of-settings)
  - [Usage of ENV vars to override settings at the instance level](#usage-of-env-vars-to-override-settings-at-the-instance-level)
- [FAQ](#faq)

## TL;DR and Quickstart

- All the domain logic lives under `ee/lib/remote_development` in the "Domain Logic layer". Unless you are changing the DB schema or API structure, your changes will probably be made here.
- The `Main` class is the entry point for each sub-module, and is found at `ee/lib/remote_development/**/main.rb`
- Have a look through the ["Railway Oriented Programming"](https://fsharpforfunandprofit.com/rop/) presentation slides (middle of that page) to understand the patterns used in the Domain Logic layer.
- Prefer `ee/spec/lib/remote_development/fast_spec_helper.rb` instead of `spec_helper` where possible. See [Avoid coupling Domain Logic layer to Rails application](#avoid-coupling-domain-logic-layer-to-rails-application).
- Use `scripts/remote_development/run-smoke-test-suite.sh` locally, to get a faster feedback than pushing to CI and waiting for a build.
- Use `scripts/remote_development/run-e2e-tests.sh` to easily run the QA E2E tests.
- If you use [RubyMine](https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/rubymine/), you will get a lot of extra help, because we try to keep the `Inspect Code` clean and green for all Remote Development files, and also maintain YARD annotations, which means you will get fast in-IDE feedback about many errors such as type violations, etc, which are not caught by the standard Gitlab static linters such as RuboCop, ESLint, etc.

### Videos

- A Knowledge Sharing session, covering most of the topics covered in this README: https://www.youtube.com/watch?v=RJrBPbBNE9Y
- A recording of a backend pairing session, where Chad presents an overview of the Remote Development architecture, covering several of the topics and patterns discussed below in this README: https://www.youtube.com/watch?v=Z6n7IKbtuDk
  - Note that in the second half of this video includes speculation on how the reconciliation logic will be redesigned to work with Railway Oriented Programming, but the [final implementation ended up looking a bit different](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/126785) (and simpler).

## Overview

### Layered architecture

In the Remote Development feature, we strive to maintain a clean, layered architecture with the business logic at the center.

```mermaid
flowchart TB
    direction TB
    Client --> controllers
    subgraph monolith[Rails Monolith]
        subgraph routinglayer[Remote Development/GitLab Agent for Kubernetes: Routing/Controller layer]
            direction TB
            controllers[Controllers]
            subgraph apilayer[Remote Development / GitLab Agent For Kubernetes: Grape/GraphQL API layer]
                direction TB
                apis[Grape APIs & GraphQL Resolvers/Mutations]
                subgraph service[Remote Development: Service layer]
                    direction TB
                    services[Services]
                    subgraph domainlogiclayer[Remote Development: Domain Logic layer]
                    domainlogic[Domain Logic modules]
                    end
                end
            end
        end
        subgraph settingslayer[Remote Development: Settings layer]
          settings[RemoteDevelopment::Settings module]
        end
        models[ActiveRecord models]
        domainlogic --> otherdomainservices[Other domain services]
        controllers --> apis
        apis --> services
        services --> domainlogic
        domainlogic --> models
        controllers --> settings
        services --> settings
        models --> settings
    end
```

The layers are designed to be _loosely coupled_, with clear interfaces and no circular dependencies, to the extent this is possible within the current GitLab Rails monolith architecture.

An example of this is how we avoid coupling the Domain Logic layer to the Service layer's `ServiceResponse` concern, which would technically be a circular dependency, since the `ServiceResponse` is owned by the Service layer. Instead of using the ServiceResponse class directly in the Domain Logic layer, we have the Domain Logic layer return a hash with the necessary entries to create a ServiceResponse object. This also provides other benefits. See the comments in [`ee/app/services/remote_development/service_response_factory.rb`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/app/services/remote_development/service_response_factory.rb#L12-12) for more details.

We also minimize the amount of logic that lives in the ActiveRecord models, and keep them as thin and dumb as possible. The only logic that currently lives on the models is related to ActiveRecord validations,
ActiveRecord lifecycle hooks, and simple aliases such as the `Workspace#url` method, which only does string concatenation. And if any of this logic in the models were to become more complex,
it should be extracted out to the Domain Logic layer where it can be decoupled and unit tested in isolation.

This overall approach is aligned with [our direction towards a more modular monolith](https://docs.gitlab.com/ee/architecture/blueprints/modular_monolith/). See that document for more information on
the motivations and patterns. Specifically, see the `References` sub-page and reference to the the [`hexagonal architecture ports and adapters`](https://www.google.com/search?q=hexagonal+architecture+ports+and+adapters&tbm=isch) pattern, which includes [this article with an example of this architecture](https://herbertograca.com/2017/11/16/explicit-architecture-01-ddd-hexagonal-onion-clean-cqrs-how-i-put-it-all-together/)

### Avoid coupling Domain Logic layer to Rails application

This layered approach also implies that we avoid directly referring to classes which are part of the Rails application from within the Domain Logic layer.

If possible, we prefer to inject instances of these classes, or the classes themselves, into the Domain Logic layer from the Service layer.

This also means that we can use `ee/spec/lib/remote_development/fast_spec_helper.rb` in most places in the Domain Logic layer. However, we may use the normal `spec_helper` for Domain Logic classes which make direct use of Rails. For example, classes which directly use ActiveRecord models and/or associations, where the usage of `fast_spec_helper` would require significant mocking, and not provide as much coverage of the ActiveRecord interactions.
See [this thread](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/126785#note_1494395384) for a more detailed discussion of when/why to use `fast_spec_helper` or not.

## Type safety

The Remote Development domain leverages type safety where _possible and pragmatic_.

We also refer to this approach as being **"as type safe as _profitable_"**.

This allows us to have some run-time safety nets in addition to test coverage, and also helps RubyMine provide useful warnings when the wrong types are used.

Although Ruby is traditionally weakly-typed, without null safety and little support for type inference, there are several options to achieve a type safety net, especially since the 3.0 release.

### Type checking

- We use [**YARD annotations**](https://yardoc.org/) for method signatures. This is used to provide warnings in IDEs such as RubyMine when incorrect types are being used. We are currently trying this out, we may not continue, or we may replace or augment it with other type safety approaches in the future.
- We do not attempt to use RBS or Sorbet (yet), as these require a more extensive investment and wider impacting changes, so any work in this area should be coordinated with the rest of the codebase.

### Union types

We also simulate ["Union Types"](https://en.wikipedia.org/wiki/Union_type) in Ruby. We do this through the use of a module which defines multiple class constants of the same type. The `RemoteDevelopment::Messages` module is an example of this.

### Pattern matching with types

#### Case statements with types

- The `case ... in` structure can be used to pattern-match on types. When used with the approach of throwing an exception in the `else` clause, this can provide exhaustive type checking at runtime.

#### Rightward assignment pattern matching and destructuring with types

Example: Given a `Hash` `x` with an entry `y` which is an `Integer`, the following code would destructure the integer into `i`:

```ruby
x = {y: 1}
x => {y: Integer => i}
puts i # 1
```

If `y` was not an integer type, a `NoMatchingPatternError` runtime exception with a descriptive message would be thrown:

```ruby
x = {y: "Not an Integer"}
x => {y: Integer => i} #  {:y=>"Not an Integer"}: Integer === "Not an integer" does not return true (NoMatchingPatternError)
```

- This is a powerful new feature of Ruby 3 which allows for type safety without requiring the use of type safety tools such as RBS or Sorbet.
- Although rightward pattern matching with types is still an [experimental feature](https://rubychangelog.com/versions-latest/), it has been stable with [little negative feedback](https://bugs.ruby-lang.org/issues/17260)).
- Also, Matz has [stated his committment to the support of rightward assignement for pattern matching](https://bugs.ruby-lang.org/issues/17260#note-1).
- But even if the experimental support for types in rightward assignment was removed, it would be straightforward to change all occurrences to remove the types and go back to regular rightward assignment. We would just lose the type safety.

Also note that `#deconstruct_keys` must be implemented in order to use these pattern matching features.

However, note that sometimes we will avoid using this type of hardcoded type checking, if it means that
we will be able to use `fast_spec_helper`, and there is otherwise sufficient test coverage to ensure
that the types are correct. See [this comment thread](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/126785#note_1494395384) for a more detailed discussion.

#### Pattern matching and destructuring without types

Also note that the destructuring a hash or array, even without the type checks (e.g. `x => {y: i}`), is still a form of type safety, because it will raise a `NoMatchingPatternKeyError` exception if the hash or array does not have the expected structure.

### Null safety

When accessing a `Hash` entry by key (outside of pattern matching), where we expect that the value must present, we prefer to use `Hash#fetch`
instead of `Hash#[]`.

### "Type signatures" in Ruby without a type system

So, in the absence of a real type system like RBS, we can consider the above patterns as **_achieving a similar effect to a type signature in a typed language_**.

This is because this type+existence checking ensures that the type requirement(s) of a cohesive method are met.

As we'll see below in the section on Railway Oriented Programming, this serves the same purpose as the typed F# signatures of the "internal" functions of the [Domain Modeling Made Functional](https://pragprog.com/titles/swdddf/domain-modeling-made-functional/) book's examples, which _do_ specify their explicit dependencies.

This may be a strange concept to people coming from compiled languages, because in Ruby this _does_ happens at runtime, like everything else in an interpreted language like Ruby.

But, we also have strict adherence to thorough testing at multiple levels of the testing pyramid, which ensures that this type-checking code is always executed during development/CI.

Thus, when viewed holistically, if you squint at it in the right way, this approach is acting as a sort of "type-safe compiler".

**_But remember that this "compiler" is only as good as your manual type checks and test coverage!_**

## Functional patterns

The domain layer of the Remote Development feature uses some Functional Programming patterns.

Although these patterns may not be common in Rails apps or the GitLab Rails monolith, they fully supported in Ruby, and are commonly used in many other languages, including other lanaguages used within GitLab, such as Javascript, Golang, and Rust. The functional patterns have benefits which we want to leverage, such as the following.

However, we try to avoid functional patterns which would add little value, and/or could be confusing and difficult to understand even if technically supported in Ruby. [`currying`](https://www.rubydoc.info/stdlib/core/Method:curry) would be an example of this.

### Immutable state

Wherever possible, we use immutable state. This leads to fewer state-related bugs, and code which is easier to understand, test, and debug. This is a common pattern, and many widely used frameworks, such as Redux and Vuex, use immutable state or controls around how state can be mutated. Immutability is also the basis of architectures such as Event Sourcing, which we [may consider for some GitLab features/domains in the future as we move towards a modular monolith](https://docs.gitlab.com/ee/architecture/blueprints/modular_monolith/references.html#reference-implementations--guides).

We enforce imutability through the usage of patterns such as [pure functions and the usage of of "singleton" (or class) methods](#pure-functions).

However, we still mutate objects in some cases _where it makes sense in the context of our patterns_. For example, the mutable context object which is used when [Passing information along the ROP chain](#passing-information-along-the-rop-chain), and this results in concise and simple code.

_Usually_, mutating parameters which are passed to a method/function is "Not A Good Idea". However, in this case, due to the nature of the architecture and these patterns as we currently use them, there is minimal risk. There would also be a risk of increased performance over if we attempted to enforce immutability. One way to frame this topic is by thinking about how we could enforce `call-by-value` vs. `call-by-reference`, and more importantly, where and when _should_ try to enforce it. Note that Ruby uses "pass by object reference", as explained by [this stackoverflow answer](https://stackoverflow.com/a/23421320/25192). See [this thread](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/150208#note_1875548528) for an extensive discussion on this topic.

### Higher order functions

["Higher order functions"](https://en.wikipedia.org/wiki/Higher-order_function) are the basis of many (or most) functional patterns. Ruby supports this by allowing lambdas, procs, or method object references to be passed as arguments to other methods.

In the Remote Development feature, we accomplish this by passing lambdas or "singleton" (class) `Method` objects as arguments.

Note that we do not use procs (and enforce their non-usage), because of their behavior with regard to arguments and the `return` keyword.

### Pure functions

We rely on ["pure functions"](https://en.wikipedia.org/wiki/Pure_function), which are necessary to support and enforce functional patterns such as immutable state and higher order functions as described above.

Instance variables are are a form of state, and are incompatible with the usage of pure functions, so we avoid their usage except in ["value object"](#value-objects) classes, which are intended only to encapsulate state in an object, but have no business logic in the class.

In Ruby, higher order functions are implemented and enforced through the usage of "singleton" or class methods, which by definition do not allow the usage of constructors and instance variables, and therefore cannot contain or reference state (unless you try to set state in a class variable, which you should never do in the context of a Rails request anyway 😉).

So, this pattern of always using class methods for our business logic _intentionally prevents us_ from holding on to any mutable state in the class, which results in classes which are easier to debug and test. We also use this approach for "`Finder`" classes and other "standalone" classes.

### Concurrency and parallelism

By using patterns such as immutable state and pure functions, we are able to support concurrency and parallelism in the domain logic, which Ruby supports though various standard library features.

This may be useful in the future for the Remote Development feature, as operations such as reconciliation of workspace state involve processing data for many independent workspaces in a single request.

### Error Handling

The domain logic of the Remote Development feature is based on the
["Railway Oriented Programming"](https://fsharpforfunandprofit.com/rop/) pattern, through the usage of a standard [`Result` class](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/result.rb) as found in many programming languages (ours is based on the [Rust implementation](https://doc.rust-lang.org/std/result/index.html)).

This Railway Oriented Programming pattern allows us to keep the business logic decoupled from logging, error handling, and tracking/observability concerns, and chain these cohesive business logic operations together in a decoupled way.

## Object-Oriented patterns

Although the functional patterns above are used when they provide benefits, we otherwise still try to adhere to standard OO/Ruby/Rails idioms and patterns, for example:

### Value Objects

When we need to pass data around, we encapsulate it in objects. This may be a standard libary class such as `Hash` or `String`, or it may be a custom class which we create.

The custom classes are a form of the ["Value Object](https://thoughtbot.com/blog/value-object-semantics-in-ruby) pattern. Currently, `RemoteDevelopment::Message` is the only example of this (NOTE: `error.rb` is also one, but it is being deprecated in favor of `Message`).

For these custom value object classes, the `#==` method should be implemented.

### Mixins/Inheritance

Mixins (implemented as modules in standard Ruby or "concerns" in Rails) are a common pattern for sharing logic in Ruby and Rails.

We prefer mixins/modules instead of superclasses/inheritance for sharing code. This is because modules (which are actually a form of [multiple inheritance](https://en.wikipedia.org/wiki/Multiple_inheritance)) provide more flexibility than single inheritance.

However, we do use inheritance in the higher layers of the architecture where this is necessary confirm with existing patterns, e.g. in controllers or API classes.

## Other Patterns

### Inversion of Control

We use the pattern of "Inversion of Control" when applicable, to help achieve loose coupling between modules which implement business logic.

In our [pure functional approach with the usage of of "singleton" (or class) methods](#pure-functions), "Inversion of Control" means "injecting" the dependencies as arguments passed to the pure functions.

An example of this is how we inject all necessary dependencies into the beginning of a [Railway Oriented Programming](#railway-oriented-programming-and-the-result-class) (ROP) chain as entried in a single context object which is of type `Hash`. Then, all the steps of the ROP chain depend upon this for all of their context.

In many cases, these business logic classes _COULD_ use static method calls to obtain their dependencies (e.g. `Rails.logger`), but we intentionally avoid that in order to maintain the pure functional approach, and avoid coupling them to the Rails infrastructure or other classes outside of our domain. This has benefits in testability (e.g. facilitating wider usage of `fast_spec_helper`).

See more details and examples of this in the sections below.

### Metaprogramming

We _currently_ do not make heavy use of metaprogramming. But, we may make use of it in the future in areas where it makes sense.

## Railway Oriented Programming and the Result class

The Domain Logic layer uses the "Railway Oriented Programming" pattern (AKA "ROP"), which is [explained here in a presentation and video](https://fsharpforfunandprofit.com/rop/) by Scott Wlaschin. The presentation slides on that page give an overview which explains the motivation and implementation of this pattern.

This pattern is also explored further in the book [Domain Modeling Made Functional](https://pragprog.com/titles/swdddf/domain-modeling-made-functional/) by the same author.

### Result class

To support this pattern, we have created a standard, reusable [`Result` class](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/result.rb).

This is a very common pattern in many languages, and our `Result` class naming and usage is based on a subset of the [Rust implementation](https://doc.rust-lang.org/std/result/index.html). It's actually a monad, but you don't have to know anything about that word in order to use it. It's [definitely _not_ a burrito](https://www.google.com/search?q=monads+are+not+burritos).

The main idea of `Result` is that it is an abstraction which encapsulates whether an operation was successful ("`ok`") or failed ("`err`"). In either case, it will contain a `value`, representing either the output of the successful operation, or some information about the failure.

The `Result#and_then` and `Result#map` methods are [higher order functions](#higher-order-functions) which support the Railway Oriented Programming pattern. They allow "function references" (which are Ruby lambdas or singleton/class `Method` object instances) to be passed, which allows them to be "chained" together, with a `Result` and its contained value being passed along the chain. If any step in the chain fails, the chain exits early.

The only difference between `Result#and_then` and `Result#map` is that reference passed to `#and_then` needs to support the possibility of an `err` failure, but the reference passed to `#map` has no possibility of failing.

All of the above is explained in much more detail in the [ROP presentation/video](https://fsharpforfunandprofit.com/rop/), as well as the Rust `Result` [documentation](https://doc.rust-lang.org/std/result/index.html) and [API](https://doc.rust-lang.org/std/result/enum.Result.html).

Note that we do not support procs to be used with result, only lambdas and class/singleton methods, for the reasons described above in the [Higher order functions](#higher-order-functions) section.

### Message class and Messages module

As shown in the examples in the ["Railway Oriented Programming" slides](https://fsharpforfunandprofit.com/rop/), we use a concept of ["Union types"](#union-types) to represent the messages passed as the `value` of a `Result` object.

The `RemoteDevelopment::Messages` (plural) module, and all of its contained message classes, is an example of this sort of "Union type".

Each of these message types is an instance of the `Message` class (singular). A `Message` instance is a [Value Object](#value-objects) which represents a single message to be contained as the `value` within a `Result`. It has single `context` attribute which must be of type `Hash`.

All of these Messsage classes represent every possible type of success and error `Result` value which can occur within the Remote Development domain.

Unlike `Result`, the `Messages` module and `Message` class are intentionally part of the `RemoteDevelopment` namespace, and are not included in the top-level `lib` directory, because they are specific to the Remote Development domain. Other domains which use `Result` may want to use their own type(s) as the `value` of a `Result`.

#### What types of errors should be handled as domain Messages?

Domain message classes should normally only be defined and used for _expected_ errors. I.e., validation or authorization
errors, yes. Infrastructure errors, or bugs in our own code, no.

The exception to this would be if you are processing multiple items or models (i.e. `Workspaces`) in a single request, and you want to
ensure that an unexpected error in one of them will not prevent the others from being processed successfully. In this case, you would
probably want to add logic to the top level of the loop which is procssing the individual items, to catch and report any possible
`StandardError`, but still continue attempting to process the remaining items.

See [this MR comment thread](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/125358#note_1469298937) for more context.

### ROP code examples

Here is an example of Railway Oriented Programming pattern, with extra code removed to focus on the patterns.

First is the Services layer using `ee/lib/remote_development/workspaces/update/main.rb` as an example, which contains no logic other than calling the `Main` class in the Domain Logic layer, and converting the return value to a `ServiceResponse`:

```ruby
class UpdateService
  attr_reader :current_user

  def initialize(current_user:)
    @current_user = current_user
  end

  def execute(workspace:, params:)
    response_hash = Update::Main.main(workspace: workspace, current_user: current_user, params: params)

    create_service_response(response_hash)
  end
end
```

Next, you see the `ee/lib/remote_development/workspaces/update/main.rb` class, which implements an ROP chain with two steps, `authorize` and `update`.

Note that the `Main` class also has no domain logic in it itself other than invoking the steps and matching the the domain messages and transforming them into a response hash. We want to avoid that coupling, because all domain logic should live in the cohesive classes that are called by `Main` via the ROP pattern:


```ruby
class Main
  def self.main(value)
    initial_result = Result.ok(value)
    result =
      initial_result
        .and_then(Authorizer.method(:authorize))
        .and_then(Updater.method(:update))

    case result
    in { err: Unauthorized => message }
      generate_error_response_from_message(message: message, reason: :unauthorized)
    in { err: WorkspaceUpdateFailed => message }
      generate_error_response_from_message(message: message, reason: :bad_request)
    in { ok: WorkspaceUpdateSuccessful => message }
      { status: :success, payload: message.context }
    else
      raise UnmatchedResultError.new(result: result)
    end
  end
end
```

...and here is an example of the `ee/lib/remote_development/workspaces/update/updater.rb` class implementing the business logic in the "chain".
In this case, it contains the cohesive logic to update a workspace, and no other
unrelated domain logic:

```ruby
class Updater
  def self.update(value)
    value => { workspace: RemoteDevelopment::Workspace => workspace, params: Hash => params }
    if workspace.update(params)
      Result.ok(WorkspaceUpdateSuccessful.new({ workspace: workspace }))
    else
      Result.err(WorkspaceUpdateFailed.new({ errors: workspace.errors }))
    end
  end
end
```

### Passing information along the ROP chain

In our implementation of Railway Oriented Programming, **we pass all "context" along the ROP/Result chain via a single `value` parameter which is a `Hash` type**. 

This allows us to avoid explicit parameters in order to reduce coupling and increase cohesion of the higher-level methods like `Main.main`. (_NOTE: Although this parameter is currently called "value", [we are considering renaming it to "context"](https://gitlab.com/gitlab-org/gitlab/-/issues/452475) to make its usage more clear, and to also be aligned with the [concept of "context" from Golang](https://www.reddit.com/r/golang/comments/18mphqt/what_even_is_context/) which many people will be familiar with_)

In other words, in these higher-level `Main.main` methods which are our "public API", and in all the classes that are steps in the ROP chain which each have their own single "public API" method, we "hide" dependency information they do not directly use. And inside these "public API" methods, we _only extract/destructure the dependencies which are directly used by the class_ from the `value` parameter `Hash`, and we _never extract or reference anything that is not directly used by that class_.

Note that "internal" methods which are _not_ part of the public API of the class may have individual arguments for their dependencies, and we usually prefer to make these [keyword arguments](https://thoughtbot.com/blog/ruby-2-keyword-arguments) for a bit of extra type safety.

This approach is aligned with the guidance from the section `Are Dependencies Part of the Design?` in the [Domain Modeling Made Functional](https://pragprog.com/titles/swdddf/domain-modeling-made-functional/) book page 137.

It says:

> ...let’s follow this guideline:
>
> - For functions exposed in a public API, hide dependency information from callers.
>
> - For functions used internally, be explicit about their dependencies.
>
> In this case, the dependencies for the top-level PlaceOrder workflow function should not be exposed, because the caller doesn’t need to know about them.

There are implementation differences for F# vs Ruby, but the sentiment is the same: _hide dependencies in places where they are not used._


## Benefits

### Loose coupling, high cohesion

These patterns, especially Railway Oriented Programming, allows us to split the Domain Logic layer more easily into small, loosely coupled, highly cohesive classes. This makes the individual classes and their unit tests easier to write and maintain.

### Minimal logic in Service layer

These patterns let all of the Service layer unit test specs be pure mock-based tests, with almost no dependencies on (or testing of) any specifics of the domain logic other than the domain classes' standard API.

### More likely that you can use fast_spec_helper

This loose coupling and high cohesion of the Domain Logic modules also makes it more likely that some of the Domain Logic unit tests can leverage `fast_spec_helper` to run in sub-second time, because they are not coupled to classes in the Rails monolith and their dependency graph (such as `ServiceResponse` currently is, due to its usage of `Gitlab::ErrorTracking`).

### Easier for Everyone to Contribute

These patterns makes the code more approachable for contributors who are less familiar with Ruby and Rails, or all of the details of our monolith.

For example, if they are simply adding a feature or fixing a bug around devfile validation, they may not need to understand anything about Rails MVC, ActiveRecord, or our application structure, because the validation classes are cohesive and focused solely on validation, and deal directly with simple devfile data structures.

These functional patterns are also widely known across many different programming languages and ecosystems, and thus are easier to understand than the standard Rails paradigms of inheritance and many concerns/mixins (AKA multiple inheritance) which are non-intuitive, and difficult to find/follow in the massive GitLab codebase.

Also, there are currently several backend engineers on the Remote Development team who have more extensive experience in Golang than Rails. Usage of these standard patterns also allows them to contribute more easily, without having to learn as many of the nuances of Rails monolith development in order to be productive and produce clean MRs.

## Differences from standard GitLab patterns

### Stateless Service layer classes

Some of the services do not strictly follow the [currently documented patterns for the GitLab service layer](https://docs.gitlab.com/ee/development/reusing_abstractions.html#service-classes), because in some cases those patterns don't cleanly apply to all of the Remote Development use cases.

For example, the reconciliation service does not act on any specific model, or any specific user, therefore it does not have any constructor arguments.

In some cases, we do still conform to the convention of passing the current_user
in the constructor of services which do reference the user, although we may change this too in the future to pass it to `#execute` and thus make it a pure function as well.

We also don't use any of the provided superclasses like BaseContainerService or its descendants, because the service contains no domain logic, and therefore these superclasses and their instance variables are not useful.

If these service classes need to be changed or standardized in the future (e.g. a standardized constructor for all Service classes across the entire application), it will be straightforward to change.

### 'describe #method' RSpec blocks are usually unnecessary

Since much of the Domain Logic layer logic is in classes with a single singleton (class) method entry point, there is no need to have `describe .method do` blocks in specs for these classes. Omitting it saves two characters worth of indentation line length. And most of these classes and methods are named with a standard and predictable convention anyway, such as `Authorizer.authorize` and `Creator.create`.

We also tend to group all base `let` fixture declarations in the top-level global describe block rather than trying to sort them out into their specific contexts, for ease of writing/maintenance/readability/consistency. Only `let` declarations which override a global one of the same name are included in a specific context.

## Remote Development Settings

### Overview of Remote Development settings module

Remote Development has a dedicated module in the domain logic for handling settings. It is
`RemoteDevelopment::Settings`. The goals of this module are:

1. Allow various methods to be used for providing settings depending on which are appropriate, including:
    - Default values
    - One of the following:
      - `::Gitlab::CurrentSettings`
      - `::Settings` (not yet supported)
      - Cascading settings via `CascadingNamespaceSettingAttribute` (not yet supported)
   - Environment variables, with the required prefix of `GITLAB_REMOTE_DEVELOPMENT_`
    - Any other current or future method
1. Perform type checking of provided settings.
1. Provide precedence rules (or validation errors/exceptions, if appropriate) if the same setting is
   defined by multiple methods. See the [Precedence of settings](#precedence-of-settings) section
   below for more details.
1. Allow usage of the same settings module from both the backend domain logic as well as the frontend
   Vue components, by obtaining necessary settings values in the Rails controller and passing them
   through to the frontend.
1. Use [inversion of control](#inversion-of-control), to avoid coupling the
   Remote Development domain logic to the rest of the monolith. At the domain logic layer
   all settings are injected and represented as a simple Hash. This injection approach also allows the
   Settings module to be used from controllers, models, or services without introducing
   direct circular dependencies at the class/module level.

### Adding a new setting

To add a new Remote Development setting with a default value which is automatically configurable
via an ENV var, add a new entry in `lib/remote_development/settings/default_settings.rb`

### Reading settings

To read a single setting, use `RemoteDevelopment::Settings.get_single_setting(:setting_name)`

To read all settings, use `RemoteDevelopment::Settings.get_all_settings`

NOTE: A setting _MUST_ have an entry defined in `lib/remote_development/settings/default_settings.rb`
to be read, but the default value can be `nil`. This will likely be the case when you want to use
a setting from `Gitlab::CurrentSettings`.

### Precedence of settings

If a setting can be defined via multiple means (e.g. via an `ENV` var the `Settings` model),
there is a clear and simple set of precedence rules for which one "wins". These follow the
order of the steps in the
[RoP `Main` class of the Remote Development Settings module](../../../lib/remote_development/settings/main.rb):

1. First, the default value is used
1. Next, one of the following values are used if defined and not `nil`:
    1. `::Gitlab::CurrentSettings`
    1. `::Gitlab::Settings` (not yet implemented)
    1. Cascading settings via `CascadingNamespaceSettingAttribute` (not yet implemented)
1. Next, an ENV values is used if defined (i.e. not `nil`). The ENV var is intentionally placed as
   the last step and highest precedence, so it can always be used to easily override any settings for
   local or temporary testing.

In future iterations, we may want to provide more control of where a specific setting comes from,
or providing specific precedence rules to override the default precedence rules. For example, we could
allow them to be specified as a new field in the defaults declaration:

```
      def self.default_settings
        # third/last field is "sources to read from and their order"
        {
          default_branch_name: [UNDEFINED, String, [:env, :current_settings]], # reads ENV var first, which can be overridden by CurrentSettings
          default_max_hours_before_termination: [24, Integer, [:current_settings, :env]], # reads CurrentSettings first, which can be overridden by ENV var
          max_hours_before_termination_limit: [120, Integer] # Uses default precedence
        }
      end
```

### Usage of ENV vars to override settings at the instance level

**All settings should eventually be configurable via the Web UI (and optionally GraphQL API)**

This means that the usage of environment variables with the prefix `GITLAB_REMOTE_DEVELOPMENT_` to control settings
is _only intended to be used for the following purposes_:

1. To support initial proof-of-concept of "early adopter" iterations, where we want to quickly make a new setting
   available for use, but have not yet done the planning or design work to create an appropriate
   UI for the setting.
1. To easily perform a global override of any setting for local or temporary testing, either in
   local development or in a test/self-managed installation.

This is why ENV vars intentionally always have the highest precedence over all other methods of providing
settings values.

## FAQ

### Why is the Result class in the top level lib directory?

It it a generic reusable implementation of the Result type, and is not specific to any domain. It is intended to be reusable by any domain in the monolith which wants to use functional patterns such as Railway Oriented Programming.

### What are all the `noinspection` comments in the code?

Thanks for asking! See a [detailed explanation here](https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/)
