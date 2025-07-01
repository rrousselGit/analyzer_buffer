Welcome to Contrail!

Contrail is a code-generator to help with client/server interaction.

This includes:

- Generation of a fully type-safe "Repository"-like object
  that can invoke any endpoint of your backend
- Support for writing a backend using a "Cloud functions"-like API
- Hot-reload support
- Middleware support
- Compile-safe dependency-injection

Using contrail, you write a backend, and a type-safe client is generated to allow
your web/mobile applications to interact with your sever.

- [Installation](#installation)
- [Getting started](#getting-started)
  - [Starting the server](#starting-the-server)
  - [Interacting with your backend in a Flutter/Web app](#interacting-with-your-backend-in-a-flutterweb-app)
- [Going further](#going-further)
  - [Relative vs Absolute route paths](#relative-vs-absolute-route-paths)
  - [Query parameters](#query-parameters)
  - [Path parameters](#path-parameters)
  - [Specifying query parameters inside client code](#specifying-query-parameters-inside-client-code)
  - [Obtaining the request's body](#obtaining-the-requests-body)
  - [Dependency injection](#dependency-injection)
  - [Middlewares](#middlewares)
    - [Parameter-level middlewares](#parameter-level-middlewares)
    - [Route-level middlewares](#route-level-middlewares)
    - [Using dependency injection inside middlewares](#using-dependency-injection-inside-middlewares)
  - [About contentType](#about-contenttype)
  - [Configuring multiple routes at once](#configuring-multiple-routes-at-once)
  - [Route resolution](#route-resolution)

## Installation

Contrail uses [build_runner]. As such, you will have to install Contrail alongside
various packages.

Consider pasting the following in your terminal:

```sh
dart pub add contrail_annotation shelf dev:code_buffer dev:build_runner
```

## Getting started

Contrail works by defining top-level functions, annotated by [Http]:

```dart
// users.dart
import 'package:contrail_annotation/contrail_annotation.dart';
import 'package:shelf/shelf.dart';

part 'my_file.g.dart';

@Http.get(
  '/users/new',
  // When using JSON as return value, Contrail will automatically
  // rely on from/toJson to communicate between the client and server.
  contentType: 'application/json',
)
Future<User> get(Request request) {
  return User(name: 'John', email: 'john@mail.com');
}
```

Then, you'll need to start [build_runner] using:

```sh
dart run build_runner watch -d
```

Doing so will generate a bunch of things:

- A `bin/server.dart`
  This is the entrypoint for your server.
- A `lib/client.dart`
  This is an SDK that can be used inside client-side applications to
  interact with your server in a type-safe manner.

### Starting the server

You can start the server locally using:

```sh
dart --enable-vm-service bin/server.dart
```

This will start the server on localhost at a given port.

**Note**:  
The `--enable-vm-service` flag is optional. But specifying it enables hot-reload!

### Interacting with your backend in a Flutter/Web app

Now that we've started a server, we can query that server using the previously generated
`lib/client.dart`.

For this, inside your Flutter/Web app, import the `client.dart` file and
instantiate the `Client` class:

```dart
// lib/main.dart
import 'client.dart';

void main() {
  // We instantiate Client and point to our server
  final client = Client(Uri.http('localhost:4221'));

  // Using Client, we can invoke the HTTP methods previously defined
  User user = await client.users.get();

  // Note how the result was automatically decoded.
  print('${user.name} ${user.email}');
}
```

## Going further

### Relative vs Absolute route paths

Contrail is a hybrid between file-based routing and other approaches.  
When using [Http], two options are possible

1. Absolute paths:

```dart
@Http.get('/my/absolute/path')
Future<User> get(Request request) => ...
```

This route can be queried at `https://my-host.com/my/absolute/path`

2. Relative paths:

```dart
// lib/src/example/users.dart

@Http.get('./new')
Future<User> get(Request request) => ...
```

When using a relative path, the URI to query this route
is based on the file location, relative to its `lib/src` folder.

Here, since the file is at `lib/src/example/users.dart`, we strip out the
`lib/src` and the `.dart`. We're left with `/example/users` ; which we'll concatenate
with `./new`.

As such, in this example the route can be queried at `https://my-host.com/example/users/new`

### Query parameters

Contrail supports primitive types as named parameters. This includes:

- `String/bool/int/double`
- `List<String/bool/int/double>`

To define query parameters, routes can specify named parameters:

```dart
@Http.get('/users')
Future<User> search(Request request, {String? search}) => ...
```

This route can be queries using either of:

```
https://my-host.com/users
https://my-host.com/users?search=John
```

**Note**:
Making `search` `required` will prevent calling this route at `https://my-host.com/users`

### Path parameters

Routes' path can optionally define path parameters.  
Path parameters are defined using `:` at the start of a path
segment, followed by a variable name:

```dart
@Http.get('/users/:id')
Future<User> get(Request request, String id) => ...
```

**Note**:
The annotated function must define a parameter with the same name
as the path parameter.

**Note**:
Path parameters can only be of types `String/bool/int/double`.

### Specifying query parameters inside client code

When using query/path parameters,
the generated `Client`, will have corresponding parameters in its API.

Consider:

```dart
@Http.get('/:filter')
Future<User> search(Request request, String filter, {int? page}) => ...
```

Then the `Client` SDK will define its `search` as followed:

```dart
Future<User> search(String filter, {int? page});
```

Meaning you can write:

```dart
User user = await client.users.get('John', page: 10);
```

### Obtaining the request's body

Contrail offers a type-safe way to interact with the request's body.
To do so, simply annotate any parameter on your route with `@body`:

```dart
@Http.patch('/users/update/:id', contentType: 'application/json')
Future<User> update(Request request, String id, @body User user) => ...
```

When doing so, Contrail will automatically invoke `User.from/toJson`.  
Similarly, the generated client SDK will define its `update` as:

```dart
Future<User> update(String id, User user);
```

Meaning your clients can do:

```dart
await clients.users.update('123', User(name: 'John'));
```

### Dependency injection

Sometimes, routes may want access to objects that are obtained outside
of the request.  
To support this, Contrail offers a built-in Dependency Injection. But it's
not any Dependency Injection. It is compile-time safe!
You cannot forget to specify a parameter :)

To inject parameters in a route, annotate any parameter using `@inject`:

```dart
@Http.get('.')
Future<User> get(Request request, @inject MyDatabase database) {
  ...
}
```

When doing so, Contrail will stop generating a `main` for your server.
Instead, you will have to define one yourself.

This is typically done by calling `serve` as followed:

```dart
// bin/main.dart
import 'package:contrail_auth/contrail_auth.dart';

import './server.dart';

Future<void> main(List<String> args) async {
  await serve(
    args,
    // The `serve` function requires any injected parameters
    database: MyDatabase(),
  );
}
```

**Note**:  
Dependency-injection is based on the associated variable's name.
If two variables have the same name, they will access the same value.

### Middlewares

Middlewares are reusable piece of code that logic before/after a request,
and that can modify both the `Request` and `Response` objects.

They are generally used for logging or authentication.
In Contrail, there are two different kinds of middlewares:

- Those which are applied on a route, to transform the request/response or run logic before/after
  (For example, logging requests/responses).
- Those used to extract metadata from the request and expose it to the request
  (Such as extracting a token from the Header and exposing a `User`)

#### Parameter-level middlewares

Some middlewares can be used as a form of custom dependency-injection.
Those enable injecting values in the request based on the content of the `Request`.

To define a parameter middleware, we define a class that implements `ParameterMiddleware`
and specify a `resolve` method.

The following example is a middleware which injects the current date
in the request.

```dart
class Now implements ParameterMiddleware {
  const Now();
  // RouteMiddlewares must define a "handle".
  // The return value can be whatever you wish to.
  DateTime resolve(Request request) => DateTime.now();
}
```

This class can then be applied on any parameter of a route:

```dart
@Http.get('/users')
Future<List<User>> all(Request request, @Now() DateTime now) {
  print('The request started at $now');
}
```

#### Route-level middlewares

Route-level middlewares are classes that implement `RouteMiddleware` and define a `handle` method.  
The following defines a logging middleware:

```dart
class Log implements RouteMiddleware {
  const Log();

  // RouteMiddlewares must define a "handle".
  Handler handle(Handler next) {
    return (request) async {
      logger.log('Request: ${request.method} ${request.url}');
      final response = await next(request);
      logger.log('Response: ${response.statusCode}');
      return response;
    };
  }
}
```

Route middlewares can then be applied on any route as followed:

```dart
@Log()
@Http.get('/users/:id')
Future<User> get(Request request) => ...
```

Alternatively, you can apply a middleware to multiple routes at once
by annotating `library`:

```dart
@Log() // Log all routes in this file
library;

@Http.get('/users/:id')
Future<User> get(Request request) => ...

@Http.delete('/users/:id')
Future<User> delete(Request request) => ...
```

#### Using dependency injection inside middlewares

All middlewares can use the dependency injection feature too, either
by using `@inject` or by relying on other "Parameter middleware".

This can be done by defining extra parameters on the `handle/resolve` method like so:

```dart
class RouteExample implements RouteMiddleware {
  const RouteExample();

  // We can specify extra parameters if they use `@inject`
  // or are Parameter middlewares
  Handler handle(
    Handler next,
    // @inject is supported
    @inject Logger logger,
    // Parameter middlewares too!
    @Now() DateTime now,
  ) {
     ...
  }
}

class ParamExample implements ParameterMiddleware {
  const ParamExample();
  // Same thing with ParameterMiddlewares:
  MyValue resolve(
    Request request,
    @inject Logger logger,
    @Now() DateTime now,
  ) => ...
}
```

### About contentType

### Configuring multiple routes at once

It is quite common that various Route-specific configurations need to be applied
on most routes.

To reduce the verbosity, Contrail offers the ability to configure routes at the file level
by annotating `library` with `@Router`:

```dart
// All routes in this file will use JSON as content-type
@Router(contentType: 'application/json')
library;

@Http.get('/users')
Future<User> get(Request request) => ...

@Http.delete('/users')
Future<User> delete(Request request) => ...
```

### Route resolution

[build_runner]: http://pub.dev/packages/build_runner
[shelf]: http://pub.dev/packages/shelf
[Http]: https://pub.dev/documentation/contrail_annotation/latest/contrail_annotation/Http-class.html
