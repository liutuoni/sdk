// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:js_ast/src/precedence.dart' as js show PRIMARY;
import 'package:front_end/src/api_unstable/dart2js.dart' show $A;

import '../common_elements.dart' show JCommonElements;
import '../elements/entities.dart';
import '../js/js.dart' as js;
import '../serialization/serialization.dart';
import '../util/util.dart';
import '../js_emitter/model.dart';
import '../constants/values.dart' show ConstantValue;
import 'namer.dart';

// TODO(joshualitt): Figure out how to subsume more of the modular naming
// framework into this approach. For example, we are still creating ModularNames
// for the entity referenced in the DeferredHolderExpression.
enum DeferredHolderExpressionKind {
  globalObjectForStaticState,
  globalObjectForConstant,
  globalObjectForInterceptors,
  globalObjectForClass,
  globalObjectForMember,
}

/// A [DeferredHolderExpression] is a deferred JavaScript expression determined
/// by the finalization of holders. It is the injection point for data or
/// code to related to holders. The actual [Expression] contained within the
/// [DeferredHolderExpression] is determined by the
/// [DeferredHolderExpressionKind], eventually, most will be a [PropertyAccess]
/// but currently all are [VariableUse]s.
class DeferredHolderExpression extends js.DeferredExpression
    implements js.AstContainer {
  static const String tag = 'deferred-holder-expression';

  final DeferredHolderExpressionKind kind;
  final Object data;
  js.Expression _value;

  @override
  final js.JavaScriptNodeSourceInformation sourceInformation;

  DeferredHolderExpression(this.kind, this.data) : sourceInformation = null;
  DeferredHolderExpression._(
      this.kind, this.data, this._value, this.sourceInformation);

  factory DeferredHolderExpression.forInterceptors() {
    return DeferredHolderExpression(
        DeferredHolderExpressionKind.globalObjectForInterceptors, null);
  }

  factory DeferredHolderExpression.forStaticState() {
    return DeferredHolderExpression(
        DeferredHolderExpressionKind.globalObjectForStaticState, null);
  }

  factory DeferredHolderExpression.readFromDataSource(DataSource source) {
    source.begin(tag);
    var kind = source.readEnum(DeferredHolderExpressionKind.values);
    Object data;
    switch (kind) {
      case DeferredHolderExpressionKind.globalObjectForClass:
        data = source.readClass();
        break;
      case DeferredHolderExpressionKind.globalObjectForMember:
        data = source.readMember();
        break;
      case DeferredHolderExpressionKind.globalObjectForConstant:
        data = source.readConstant();
        break;
      case DeferredHolderExpressionKind.globalObjectForInterceptors:
      case DeferredHolderExpressionKind.globalObjectForStaticState:
        // no entity.
        break;
    }
    source.end(tag);
    return DeferredHolderExpression(kind, data);
  }

  void writeToDataSink(DataSink sink) {
    sink.begin(tag);
    sink.writeEnum(kind);
    switch (kind) {
      case DeferredHolderExpressionKind.globalObjectForClass:
        sink.writeClass(data);
        break;
      case DeferredHolderExpressionKind.globalObjectForMember:
        sink.writeMember(data);
        break;
      case DeferredHolderExpressionKind.globalObjectForConstant:
        sink.writeConstant(data);
        break;
      case DeferredHolderExpressionKind.globalObjectForInterceptors:
      case DeferredHolderExpressionKind.globalObjectForStaticState:
        // no entity.
        break;
    }
    sink.end(tag);
  }

  set value(js.Expression value) {
    assert(!isFinalized && value != null);
    _value = value;
  }

  @override
  js.Expression get value {
    assert(isFinalized, '$this is unassigned');
    return _value;
  }

  @override
  bool get isFinalized => _value != null;

  @override
  DeferredHolderExpression withSourceInformation(
      js.JavaScriptNodeSourceInformation newSourceInformation) {
    if (newSourceInformation == sourceInformation) return this;
    if (newSourceInformation == null) return this;
    return DeferredHolderExpression._(kind, data, _value, newSourceInformation);
  }

  @override
  int get precedenceLevel => _value?.precedenceLevel ?? js.PRIMARY;

  @override
  int get hashCode {
    return Hashing.objectsHash(kind, data);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeferredHolderExpression &&
        kind == other.kind &&
        data == other.data;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write('DeferredHolderExpression(kind=$kind,data=$data,');
    sb.write('value=$_value)');
    return sb.toString();
  }

  @override
  Iterable<js.Node> get containedNodes => isFinalized ? [_value] : const [];
}

/// A [DeferredHolderParameter] is a deferred JavaScript expression determined
/// by the finalization of holders. It is the injection point for data or
/// code to related to holders. This class does not support serialization.
/// TODO(joshualitt): Today this exists just for the static state holder.
/// Ideally we'd be able to treat the static state holder like other holders.
class DeferredHolderParameter extends js.Expression implements js.Parameter {
  String _name;

  @override
  final bool allowRename = false;

  @override
  final js.JavaScriptNodeSourceInformation sourceInformation;

  DeferredHolderParameter() : sourceInformation = null;
  DeferredHolderParameter._(this._name, this.sourceInformation);

  set name(String name) {
    assert(!isFinalized && name != null);
    _name = name;
  }

  @override
  String get name {
    assert(isFinalized, '$this is unassigned');
    return _name;
  }

  @override
  bool get isFinalized => _name != null;

  @override
  DeferredHolderParameter withSourceInformation(
      js.JavaScriptNodeSourceInformation newSourceInformation) {
    if (newSourceInformation == sourceInformation) return this;
    if (newSourceInformation == null) return this;
    return DeferredHolderParameter._(_name, newSourceInformation);
  }

  @override
  int get precedenceLevel => js.PRIMARY;

  @override
  T accept<T>(js.NodeVisitor<T> visitor) => visitor.visitParameter(this);

  @override
  R accept1<R, A>(js.NodeVisitor1<R, A> visitor, A arg) =>
      visitor.visitParameter(this, arg);

  @override
  void visitChildren<T>(js.NodeVisitor<T> visitor) {}

  @override
  void visitChildren1<R, A>(js.NodeVisitor1<R, A> visitor, A arg) {}

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write('DeferredHolderParameter(name=$_name)');
    return sb.toString();
  }
}

enum DeferredHolderResourceKind {
  mainFragment,
  deferredFragment,
}

/// A [DeferredHolderResource] is a deferred JavaScript statement determined by
/// the finalization of holders. Each fragment contains one
/// [DeferredHolderResource]. The actual [Statement] contained with the
/// [DeferredHolderResource] will be determined by the
/// [DeferredHolderResourceKind]. These [Statement]s differ considerably
/// depending on where they are used in the AST. This class is created by the
/// fragment emitter so does not need to support serialization.
class DeferredHolderResource extends js.DeferredStatement
    implements js.AstContainer {
  DeferredHolderResourceKind kind;
  // Each resource has a distinct name.
  String name;
  List<Fragment> fragments;
  Map<Entity, List<js.Property>> holderCode;
  js.Statement _statement;

  @override
  final js.JavaScriptNodeSourceInformation sourceInformation;

  DeferredHolderResource(this.kind, this.name, this.fragments, this.holderCode)
      : sourceInformation = null;

  DeferredHolderResource._(this.kind, this.name, this.fragments,
      this.holderCode, this._statement, this.sourceInformation);

  bool get isMainFragment => kind == DeferredHolderResourceKind.mainFragment;

  set statement(js.Statement statement) {
    assert(!isFinalized && statement != null);
    _statement = statement;
  }

  @override
  js.Statement get statement {
    assert(isFinalized, 'DeferredHolderResource is unassigned');
    return _statement;
  }

  @override
  bool get isFinalized => _statement != null;

  @override
  DeferredHolderResource withSourceInformation(
      js.JavaScriptNodeSourceInformation newSourceInformation) {
    if (newSourceInformation == sourceInformation) return this;
    if (newSourceInformation == null) return this;
    return DeferredHolderResource._(kind, this.name, this.fragments, holderCode,
        _statement, newSourceInformation);
  }

  @override
  Iterable<js.Node> get containedNodes => isFinalized ? [_statement] : const [];

  @override
  void visitChildren<T>(js.NodeVisitor<T> visitor) {
    _statement?.accept<T>(visitor);
  }

  @override
  void visitChildren1<R, A>(js.NodeVisitor1<R, A> visitor, A arg) {
    _statement?.accept1<R, A>(visitor, arg);
  }
}

const String mainResourceName = 'MAIN';

abstract class DeferredHolderExpressionFinalizer {
  /// Collects DeferredHolderExpressions from the JavaScript
  /// AST [code] and associates it with [resourceName].
  void addCode(String resourceName, js.Node code);

  /// Performs analysis on all collected DeferredHolderExpression nodes
  /// finalizes the values to expressions to access the holders.
  void finalize();

  /// The below registration functions are for use only by the visitor.
  void registerDeferredHolderExpression(
      String resourceName, DeferredHolderExpression node);
  void registerDeferredHolderResource(DeferredHolderResource node);
  void registerDeferredHolderParameter(DeferredHolderParameter node);
}

/// An abstraction representing a [Holder] object, which will contain some
/// portion of the programs code.
class Holder {
  final String key;
  final Map<String, int> refCountPerResource = {};
  final Map<String, String> localNames = {};
  final Map<String, List<js.Property>> propertiesPerResource = {};
  int _index;
  int _hashCode;

  Holder(this.key);

  int refCount(String resource) {
    assert(refCountPerResource.containsKey(resource));
    return refCountPerResource[resource];
  }

  String localName(String resource) {
    assert(localNames.containsKey(resource));
    return localNames[resource];
  }

  void setLocalName(String resource, String name) {
    assert(!localNames.containsKey(resource));
    localNames[resource] = name;
  }

  void registerUse(String resource) {
    refCountPerResource.update(resource, (count) => count + 1,
        ifAbsent: () => 0);
  }

  void registerUpdate(String resource, List<js.Property> properties) {
    (propertiesPerResource[resource] ??= []).addAll(properties);
    registerUse(resource);
  }

  int get index {
    assert(_index != null);
    return _index;
  }

  set index(int newIndex) {
    assert(_index == null);
    _index = newIndex;
  }

  @override
  bool operator ==(that) {
    return that is Holder && key == that.key;
  }

  @override
  int get hashCode {
    return _hashCode ??= Hashing.objectsHash(key);
  }
}

/// [DeferredHolderExpressionFinalizerImpl] finalizes
/// [DeferredHolderExpression]s, [DeferredHolderParameter]s,
/// [DeferredHolderResource]s, [DeferredHolderResourceExpression]s.
class DeferredHolderExpressionFinalizerImpl
    implements DeferredHolderExpressionFinalizer {
  _DeferredHolderExpressionCollectorVisitor _visitor;
  final Map<String, List<DeferredHolderExpression>> holderReferences = {};
  final List<DeferredHolderParameter> holderParameters = [];
  final List<DeferredHolderResource> holderResources = [];
  final Map<String, Set<Holder>> holdersPerResource = {};
  final JCommonElements _commonElements;
  final bool enableMinification;
  final Holder globalObjectForStaticState =
      Holder(globalObjectNameForStaticState());
  final Holder globalObjectForInterceptors =
      Holder(globalObjectNameForInterceptors());
  final Set<Holder> allHolders = {};
  DeferredHolderResource mainHolderResource;
  Holder mainHolder;
  Holder mainConstantHolder;

  /// Maps of various object types to the holders they ended up in.
  final Map<ClassEntity, Holder> classEntityMap = {};
  final Map<ConstantValue, Holder> constantValueMap = {};
  final Map<MemberEntity, Holder> memberEntityMap = {};

  DeferredHolderExpressionFinalizerImpl(this._commonElements,
      {this.enableMinification = true}) {
    _visitor = _DeferredHolderExpressionCollectorVisitor(this);
  }

  @override
  void addCode(String resourceName, js.Node code) {
    _visitor.setResourceNameAndVisit(resourceName, code);
  }

  Holder _lookup<T>(T data, LibraryEntity library, Map<T, Holder> map) {
    if (library == _commonElements.interceptorsLibrary) {
      return globalObjectForInterceptors;
    }
    // See the below note on globalObjectForConstants.
    return map[data] ?? mainHolder;
  }

  /// Returns true if [element] is stored in the static state holder
  /// ([staticStateHolder]).  We intend to store only mutable static state
  /// there, whereas constants are stored in 'C'. Functions, accessors,
  /// classes, etc. are stored in one of the other objects in
  /// [reservedGlobalObjectNames].
  bool _isPropertyOfStaticStateHolder(MemberEntity element) {
    // TODO(ahe): Make sure this method's documentation is always true and
    // remove the word "intend".
    return element.isField;
  }

  Holder globalObjectForMember(MemberEntity entity) {
    if (_isPropertyOfStaticStateHolder(entity)) {
      return globalObjectForStaticState;
    } else {
      return _lookup(entity, entity.library, memberEntityMap);
    }
  }

  Holder globalObjectForClass(ClassEntity entity) {
    return _lookup(entity, entity.library, classEntityMap);
  }

  static String globalObjectNameForStaticState() => r'$';

  static String globalObjectNameForInterceptors() => 'J';

  Holder globalObjectForConstant(ConstantValue constant) {
    // TODO(46009): There is a bug where constants are referenced without being
    // emitted. However, in practice it may not matter because these constants
    // may not be used. Until this bug is fixed, we say these constants are in
    // the [mainHolder] even though they aren't in the code at all.
    return constantValueMap[constant] ?? mainConstantHolder;
  }

  Holder globalObjectForEntity(Entity entity) {
    if (entity is MemberEntity) {
      return globalObjectForMember(entity);
    } else if (entity is ClassEntity) {
      return globalObjectForClass(entity);
    } else {
      assert((entity as LibraryEntity) == _commonElements.interceptorsLibrary);
      return globalObjectForInterceptors;
    }
  }

  /// Registers a [holder] use within a given [resource], if [properties] are
  /// provided then it is assumed this is an update to a holder.
  void registerHolderUseOrUpdate(String resourceName, Holder holder,
      {List<js.Property> properties}) {
    if (properties == null) {
      holder.registerUse(resourceName);
    } else {
      holder.registerUpdate(resourceName, properties);
    }
    allHolders.add(holder);
    (holdersPerResource[resourceName] ??= {}).add(holder);
  }

  /// Returns a global object for a given [Object] based on the
  /// [DeferredHolderExpressionKind].
  Holder kindToHolder(DeferredHolderExpressionKind kind, Object data) {
    switch (kind) {
      case DeferredHolderExpressionKind.globalObjectForInterceptors:
        return globalObjectForInterceptors;
      case DeferredHolderExpressionKind.globalObjectForClass:
        return globalObjectForClass(data);
      case DeferredHolderExpressionKind.globalObjectForMember:
        return globalObjectForMember(data);
      case DeferredHolderExpressionKind.globalObjectForConstant:
        return globalObjectForConstant(data);
      case DeferredHolderExpressionKind.globalObjectForStaticState:
        return globalObjectForStaticState;
    }
    throw UnsupportedError("Unreachable");
  }

  /// Finalizes [DeferredHolderParameter]s.
  void finalizeParameters() {
    for (var parameter in holderParameters) {
      if (parameter.isFinalized) continue;
      parameter.name = globalObjectNameForStaticState();
    }
  }

  /// Finalizes all of the [DeferredHolderExpression]s associated with a
  /// [DeferredHolderResource].
  void finalizeReferences(DeferredHolderResource resource) {
    var resourceName = resource.name;
    if (!holderReferences.containsKey(resourceName)) return;
    for (var reference in holderReferences[resourceName]) {
      if (reference.isFinalized) continue;
      var holder = kindToHolder(reference.kind, reference.data);
      js.Expression value = js.VariableUse(holder.localName(resourceName));
      reference.value =
          value.withSourceInformation(reference.sourceInformation);
    }
  }

  /// Registers all of the holders used in the entire program.
  void registerHolders() {
    // Register all holders used in all [DeferredHolderResource]s.
    for (var resource in holderResources) {
      resource.holderCode.forEach((entity, properties) {
        Holder holder = globalObjectForEntity(entity);
        registerHolderUseOrUpdate(resource.name, holder,
            properties: properties);
      });
    }

    // Register all holders used in [DeferredHolderReference]s.
    holderReferences.forEach((resource, references) {
      for (var reference in references) {
        var holder = kindToHolder(reference.kind, reference.data);
        registerHolderUseOrUpdate(resource, holder);
      }
    });

    // Finally, because all holders are needed in the main holder, we register
    // their use here.
    for (var holder in allHolders) {
      registerHolderUseOrUpdate(mainHolderResource.name, holder);
    }
  }

  /// Returns an [Iterable<Holder>] containing all of the holders used within a
  /// given [DeferredHolderResource] except the static state holder (if any).
  Iterable<Holder> nonStaticStateHolders(DeferredHolderResource resource) {
    if (!holdersPerResource.containsKey(resource.name)) return [];
    return holdersPerResource[resource.name]
        .where((holder) => holder != globalObjectForStaticState);
  }

  /// Generates code to declare holders for a given [resourceName].
  HolderInitCode declareHolders(String resourceName, Iterable<Holder> holders,
      {bool initializeEmptyHolders = false}) {
    // Create holder initialization code. If there are no properties
    // associated with a given holder in this specific [DeferredHolderResource]
    // then it will be omitted. However, in some cases, i.e. the main output
    // unit, we still want to declare the holder with an empty object literal
    // which will be filled in later by another [DeferredHolderResource], i.e.
    // in a specific deferred fragment. The generated code looks like this:
    //
    //    {
    //      var H = {...}, ..., G = {...};
    //    }

    List<Holder> activeHolders = [];
    List<js.VariableInitialization> holderInitializations = [];
    for (var holder in holders) {
      var holderName = holder.localName(resourceName);
      List<js.Property> properties =
          holder.propertiesPerResource[resourceName] ?? [];
      if (properties.isEmpty) {
        holderInitializations.add(js.VariableInitialization(
            js.VariableDeclaration(holderName, allowRename: false),
            initializeEmptyHolders ? js.ObjectInitializer(properties) : null));
      } else {
        activeHolders.add(holder);
        holderInitializations.add(js.VariableInitialization(
            js.VariableDeclaration(holderName, allowRename: false),
            js.ObjectInitializer(properties)));
      }
    }

    // Create statement to initialize holders.
    var initStatement = js.ExpressionStatement(
        js.VariableDeclarationList(holderInitializations, indentSplits: false));
    return HolderInitCode(holders, activeHolders, initStatement);
  }

  /// Finalizes [resource] to code that updates holders. [resource] must be in
  /// the AST of a deferred fragment.
  void updateHolders(DeferredHolderResource resource) {
    var resourceName = resource.name;
    final holderCode =
        declareHolders(resourceName, nonStaticStateHolders(resource));

    // Set names if necessary on deferred holders list.
    js.Expression deferredHoldersList = js.ArrayInitializer(holderCode
        .activeHolders
        .map((holder) => js.js("#", holder.localName(resourceName)))
        .toList(growable: false));
    js.Statement setNames = js.js.statement(
        'hunkHelpers.setFunctionNamesIfNecessary(#deferredHoldersList)',
        {'deferredHoldersList': deferredHoldersList});

    // Update holder assignments.
    List<js.Statement> updateHolderAssignments = [
      if (holderCode.allHolders.isNotEmpty) holderCode.statement,
      setNames
    ];
    for (var holder in holderCode.allHolders) {
      var holderName = holder.localName(resourceName);
      var holderIndex = js.number(holder.index);
      if (holderCode.activeHolders.contains(holder)) {
        updateHolderAssignments.add(js.js.statement(
            '#holder = hunkHelpers.updateHolder(holdersList[#index], #holder)',
            {'index': holderIndex, 'holder': js.VariableUse(holderName)}));
      } else {
        // TODO(sra): Change declaration followed by assignments to declarations
        // with initialization.
        updateHolderAssignments.add(js.js.statement(
            '#holder = holdersList[#index]',
            {'index': holderIndex, 'holder': js.VariableUse(holderName)}));
      }
    }

    // Create a single block of all statements.
    resource.statement = js.Block(updateHolderAssignments);
  }

  /// Declares all holders in the [DeferredHolderResource] representing the main
  /// fragment.
  void declareHoldersInMainResource() {
    // Declare holders in main output unit.
    var holders = nonStaticStateHolders(mainHolderResource);
    var mainHolderResourceName = mainHolderResource.name;
    var holderCode = declareHolders(mainHolderResourceName, holders,
        initializeEmptyHolders: true);

    // Create holder uses and init holder indices.
    List<js.VariableUse> holderUses = [];
    int i = 0;
    for (var holder in holders) {
      holder.index = i++;
      holderUses.add(js.VariableUse(holder.localName(mainHolderResourceName)));
    }

    // Create holders array statement.
    //    {
    //      var holders = [ H, ..., G ];
    //    }
    var holderArray =
        js.js.statement('var holders = #', js.ArrayInitializer(holderUses));

    mainHolderResource.statement =
        js.Block([holderCode.statement, holderArray]);
  }

  /// Initializes local names for [Holder] objects, and also performs frequency
  /// based renaming if requested.
  void setLocalHolderNames() {
    bool shouldMinify(Holder holder) {
      // We minify all holders if minification is enabled, except for holders
      // which are already minified.
      return enableMinification &&
          holder != globalObjectForStaticState &&
          holder != globalObjectForInterceptors;
    }

    holdersPerResource.forEach((resource, holders) {
      // Sort holders by reference count within this resource.
      var sortedHolders = holders.toList(growable: false);
      sortedHolders.sort((a, b) {
        return b.refCount(resource).compareTo(a.refCount(resource));
      });

      // Assign names based on frequency. This will be ignored unless
      // minification is enabled.
      var reservedNames = Namer.reservedCapitalizedGlobalSymbols
          .union({globalObjectNameForInterceptors()});
      var namer = TokenScope(initialChar: $A, illegalNames: reservedNames);
      for (var holder in sortedHolders) {
        // We will use minified local names for all holders, unless minification
        // is disabled or the holder is the static state holder.
        String localHolderName;
        if (shouldMinify(holder)) {
          localHolderName = namer.getNextName();
        } else {
          localHolderName = holder.key;
        }
        holder.setLocalName(resource, localHolderName);
      }
    });
  }

  /// Initializes [Holder] objects with their default names and sets up maps of
  /// [Entity] / [ConstantValue] to [Holder].
  void initializeHolders() {
    void _addMembers(Holder holder, List<Method> methods) {
      for (var method in methods) {
        memberEntityMap[method.element] = holder;
        if (method is DartMethod) {
          _addMembers(holder, method.parameterStubs);
        }
      }
    }

    void _addClass(Holder holder, Class cls) {
      classEntityMap[cls.element] = holder;
      _addMembers(holder, cls.methods);
      _addMembers(holder, cls.isChecks);
      _addMembers(holder, cls.checkedSetters);
      _addMembers(holder, cls.gettersSetters);
      _addMembers(holder, cls.callStubs);
      _addMembers(holder, cls.noSuchMethodStubs);
      if (cls.nativeExtensions != null) {
        for (var extClass in cls.nativeExtensions) {
          _addClass(holder, extClass);
        }
      }
    }

    for (var resource in holderResources) {
      // Our default names are either 'MAIN,' 'PART<N>', or '<NAME>_C'.
      var holderName =
          resource.isMainFragment ? mainResourceName : 'part${resource.name}';
      holderName = holderName.toUpperCase();
      var holder = Holder(holderName);

      // Constant properties are not unique globally and must live in their own
      // holder.
      var constantHolder = Holder('${holderName}_C');

      // Initialize the [mainHolder] and [mainConstantHolder].
      if (resource.isMainFragment) {
        mainHolder = holder;
        mainConstantHolder = constantHolder;
      }

      for (var fragment in resource.fragments) {
        for (var constant in fragment.constants) {
          constantValueMap[constant.value] = constantHolder;
        }
        for (var library in fragment.libraries) {
          for (var cls in library.classes) {
            _addClass(holder, cls);
          }
          for (var staticMethod in library.statics) {
            memberEntityMap[staticMethod.element] = holder;
          }
        }
      }
    }
  }

  /// Allocates all [DeferredHolderResource]s and finalizes the associated
  /// [DeferredHolderExpression]s.
  void allocateResourcesAndFinalizeReferences() {
    // First finalize all holders in the main output unit.
    declareHoldersInMainResource();

    // Next finalize all [DeferredHolderResource]s.
    for (var resource in holderResources) {
      switch (resource.kind) {
        case DeferredHolderResourceKind.mainFragment:
          // There should only be one main resource and at this point it
          // should have already been finalized.
          assert(mainHolderResource == resource && resource.isFinalized);
          break;
        case DeferredHolderResourceKind.deferredFragment:
          updateHolders(resource);
          break;
      }
      finalizeReferences(resource);
    }
  }

  @override
  void finalize() {
    initializeHolders();
    registerHolders();
    setLocalHolderNames();
    finalizeParameters();
    allocateResourcesAndFinalizeReferences();
  }

  @override
  void registerDeferredHolderExpression(
      String resourceName, DeferredHolderExpression node) {
    (holderReferences[resourceName] ??= []).add(node);
  }

  @override
  void registerDeferredHolderResource(DeferredHolderResource node) {
    if (node.isMainFragment) {
      assert(mainHolderResource == null);
      mainHolderResource = node;
    }
    holderResources.add(node);
  }

  @override
  void registerDeferredHolderParameter(DeferredHolderParameter node) {
    holderParameters.add(node);
  }
}

/// Scans a JavaScript AST to collect all the [DeferredHolderExpression],
/// [DeferredHolderParameter], [DeferredHolderResource], and
/// [DeferredHolderResourceExpression] nodes.
///
/// The state is kept in the finalizer so that this scan could be extended to
/// look for other deferred expressions in one pass.
class _DeferredHolderExpressionCollectorVisitor extends js.BaseVisitor<void> {
  String resourceName;
  final DeferredHolderExpressionFinalizer _finalizer;

  _DeferredHolderExpressionCollectorVisitor(this._finalizer);

  void setResourceNameAndVisit(String resourceName, js.Node code) {
    this.resourceName = resourceName;
    code.accept(this);
    this.resourceName = null;
  }

  @override
  void visitNode(js.Node node) {
    assert(node is! DeferredHolderExpression);
    if (node is js.AstContainer) {
      for (js.Node element in node.containedNodes) {
        element.accept(this);
      }
    } else {
      super.visitNode(node);
    }
  }

  @override
  void visitDeferredExpression(js.DeferredExpression node) {
    if (node is DeferredHolderExpression) {
      assert(resourceName != null);
      _finalizer.registerDeferredHolderExpression(resourceName, node);
    } else {
      visitNode(node);
    }
  }

  @override
  void visitDeferredStatement(js.DeferredStatement node) {
    if (node is DeferredHolderResource) {
      _finalizer.registerDeferredHolderResource(node);
    } else {
      visitNode(node);
    }
  }

  @override
  void visitParameter(js.Parameter node) {
    if (node is DeferredHolderParameter) {
      _finalizer.registerDeferredHolderParameter(node);
    } else {
      visitNode(node);
    }
  }
}

class HolderInitCode {
  final Iterable<Holder> allHolders;
  final List<Holder> activeHolders;
  final js.Statement statement;
  HolderInitCode(this.allHolders, this.activeHolders, this.statement);
}

/// All of the code below this point is legacy code.

/// [DeferredHolderExpressionFinalizerImpl] finalizes
/// [DeferredHolderExpression]s, [DeferredHolderParameter]s,
/// [DeferredHolderResource]s, [DeferredHolderResourceExpression]s.
class LegacyDeferredHolderExpressionFinalizerImpl
    implements DeferredHolderExpressionFinalizer {
  _DeferredHolderExpressionCollectorVisitor _visitor;
  final List<DeferredHolderExpression> holderReferences = [];
  final List<DeferredHolderParameter> holderParameters = [];
  final List<DeferredHolderResource> holderResources = [];
  final Set<String> _uniqueHolders = {};
  final List<String> _holders = [];
  final Map<Entity, String> _entityMap = {};
  final JCommonElements _commonElements;

  LegacyDeferredHolderExpressionFinalizerImpl(this._commonElements) {
    _visitor = _DeferredHolderExpressionCollectorVisitor(this);
  }

  @override
  void addCode(String resourceName, js.Node code) {
    _visitor.setResourceNameAndVisit(resourceName, code);
  }

  final List<String> userGlobalObjects =
      List.from(Namer.reservedGlobalObjectNames)
        ..remove('C')
        ..remove('H')
        ..remove('J')
        ..remove('P')
        ..remove('W');

  /// Returns the [reservedGlobalObjectNames] for [library].
  String globalObjectForLibrary(LibraryEntity library) {
    if (library == _commonElements.interceptorsLibrary) return 'J';
    Uri uri = library.canonicalUri;
    if (uri.scheme == 'dart') {
      if (uri.path == 'html') return 'W';
      if (uri.path.startsWith('_')) return 'H';
      return 'P';
    }
    return userGlobalObjects[library.name.hashCode % userGlobalObjects.length];
  }

  /// Returns true if [element] is stored in the static state holder
  /// ([staticStateHolder]).  We intend to store only mutable static state
  /// there, whereas constants are stored in 'C'. Functions, accessors,
  /// classes, etc. are stored in one of the other objects in
  /// [reservedGlobalObjectNames].
  bool _isPropertyOfStaticStateHolder(MemberEntity element) {
    // TODO(ahe): Make sure this method's documentation is always true and
    // remove the word "intend".
    return element.isField;
  }

  String globalObjectForMember(MemberEntity entity) {
    if (_isPropertyOfStaticStateHolder(entity)) {
      return globalObjectForStaticState();
    } else {
      return globalObjectForLibrary(entity.library);
    }
  }

  String globalObjectForClass(ClassEntity entity) {
    return globalObjectForLibrary(entity.library);
  }

  String globalObjectForInterceptors() => 'J';

  String globalObjectForStaticState() => r'$';

  String globalObjectForConstants() => 'C';

  String globalObjectForEntity(Entity entity) {
    if (entity is MemberEntity) {
      return globalObjectForMember(entity);
    } else if (entity is ClassEntity) {
      return globalObjectForLibrary(entity.library);
    } else {
      assert(entity is LibraryEntity);
      return globalObjectForLibrary(entity);
    }
  }

  /// Registers an [Entity] with a specific [holder].
  void registerHolderUse(String holder, Object data) {
    if (_uniqueHolders.add(holder)) _holders.add(holder);
    if (data != null && data is Entity) {
      assert(!_entityMap.containsKey(data) || _entityMap[data] == holder);
      _entityMap[data] = holder;
    }
  }

  /// Returns a global object for a given [Object] based on the
  /// [DeferredHolderExpressionKind].
  String kindToHolder(DeferredHolderExpressionKind kind, Object data) {
    switch (kind) {
      case DeferredHolderExpressionKind.globalObjectForInterceptors:
        return globalObjectForInterceptors();
      case DeferredHolderExpressionKind.globalObjectForClass:
        return globalObjectForClass(data);
      case DeferredHolderExpressionKind.globalObjectForMember:
        return globalObjectForMember(data);
      case DeferredHolderExpressionKind.globalObjectForConstant:
        return globalObjectForConstants();
      case DeferredHolderExpressionKind.globalObjectForStaticState:
        return globalObjectForStaticState();
    }
    throw UnsupportedError("Unreachable");
  }

  /// Finalizes [DeferredHolderExpression]s [DeferredHolderParameter]s.
  void finalizeReferences() {
    // Finalize [DeferredHolderExpression]s and registers holder usage.
    for (var reference in holderReferences) {
      if (reference.isFinalized) continue;
      Object data = reference.data;
      String holder = kindToHolder(reference.kind, data);
      js.Expression value = js.VariableUse(holder);
      registerHolderUse(holder, data);
      reference.value =
          value.withSourceInformation(reference.sourceInformation);
    }

    // Finalize [DeferredHolderParameter]s.
    for (var parameter in holderParameters) {
      if (parameter.isFinalized) continue;
      parameter.name = globalObjectForStaticState();
    }
  }

  /// Registers all of the holders used by a given [DeferredHolderResource].
  void registerHolders(DeferredHolderResource resource) {
    for (var entity in resource.holderCode.keys) {
      var holder = globalObjectForEntity(entity);
      registerHolderUse(holder, entity);
    }
  }

  /// Returns a [List<String>] containing all of the holders except the static
  /// state holder.
  List<String> get nonStaticStateHolders {
    return _holders
        .where((holder) => holder != globalObjectForStaticState())
        .toList(growable: false);
  }

  /// Generates code to declare holders.
  LegacyHolderCode declareHolders(DeferredHolderResource resource) {
    // Collect all holders except the static state holder. Then, create a map of
    // holder to list of properties which are associated with that holder, but
    // only with respect to a given [DeferredHolderResource]. Each fragment will
    // have its own [DeferredHolderResource] and associated code.
    Map<String, List<js.Property>> codePerHolder = {};
    final holders = nonStaticStateHolders;
    for (var holder in holders) {
      codePerHolder[holder] = [];
    }

    final holderCode = resource.holderCode;
    holderCode.forEach((entity, properties) {
      assert(_entityMap.containsKey(entity));
      var holder = _entityMap[entity];
      assert(codePerHolder.containsKey(holder));
      codePerHolder[holder].addAll(properties);
    });

    // Create holder initialization code based on the [codePerHolder]. If there
    // are no properties associated with a given holder in this specific
    // [DeferredHolderResource] then it will be omitted. However, in some cases,
    // i.e. the main output unit, we still want to declare the holder with an
    // empty object literal which will be filled in later by another
    // [DeferredHolderResource], i.e. in a specific deferred fragment.
    // The generated code looks like this:
    //
    //    {
    //      var H = {...}, ..., G = {...};
    //      var holders = [ H, ..., G ]; // Main unit only.
    //    }

    List<String> activeHolders = [];
    List<js.VariableInitialization> holderInitializations = [];
    for (var holder in holders) {
      List<js.Property> properties = codePerHolder[holder];
      if (properties.isEmpty) {
        holderInitializations.add(js.VariableInitialization(
            js.VariableDeclaration(holder, allowRename: false),
            resource.isMainFragment ? js.ObjectInitializer(properties) : null));
      } else {
        activeHolders.add(holder);
        holderInitializations.add(js.VariableInitialization(
            js.VariableDeclaration(holder, allowRename: false),
            js.ObjectInitializer(properties)));
      }
    }

    List<js.Statement> statements = [];
    statements.add(js.ExpressionStatement(js.VariableDeclarationList(
        holderInitializations,
        indentSplits: false)));
    if (resource.isMainFragment) {
      statements.add(js.js.statement(
          'var holders = #',
          js.ArrayInitializer(holders
              .map((holder) => js.VariableUse(holder))
              .toList(growable: false))));
    }
    return LegacyHolderCode(activeHolders, statements);
  }

  /// Finalizes [resource] to code that updates holders. [resource] must be in
  /// the AST of a deferred fragment.
  void updateHolders(DeferredHolderResource resource) {
    // Declare holders.
    final holderCode = declareHolders(resource);

    // Set names if necessary on deferred holders list.
    js.Expression deferredHoldersList = js.ArrayInitializer(holderCode
        .activeHolders
        .map((holder) => js.js("#", holder))
        .toList(growable: false));
    js.Statement setNames = js.js.statement(
        'hunkHelpers.setFunctionNamesIfNecessary(#deferredHoldersList)',
        {'deferredHoldersList': deferredHoldersList});

    // Update holder assignments.
    final holders = nonStaticStateHolders;
    List<js.Statement> updateHolderAssignments = [setNames];
    for (int i = 0; i < holders.length; i++) {
      var holder = holders[i];
      if (holderCode.activeHolders.contains(holder)) {
        updateHolderAssignments.add(js.js.statement(
            '#holder = hunkHelpers.updateHolder(holdersList[#index], #holder)',
            {'index': js.number(i), 'holder': js.VariableUse(holder)}));
      } else {
        // TODO(sra): Change declaration followed by assignments to declarations
        // with initialization.
        updateHolderAssignments.add(js.js.statement(
            '#holder = holdersList[#index]',
            {'index': js.number(i), 'holder': js.VariableUse(holder)}));
      }
    }

    // Create a single block of all statements.
    List<js.Statement> statements = holderCode.statements
        .followedBy(updateHolderAssignments)
        .toList(growable: false);
    resource.statement = js.Block(statements);
  }

  /// Allocates all [DeferredHolderResource]s and
  /// [DeferredHolderResourceExpression]s.
  void allocateResources() {
    // First ensure all holders used in all [DeferredHolderResource]s have been
    // allocated.
    for (var resource in holderResources) {
      registerHolders(resource);
    }
    _holders.sort();

    // Next finalize all [DeferredHolderResource]s.
    for (var resource in holderResources) {
      switch (resource.kind) {
        case DeferredHolderResourceKind.mainFragment:
          var holderCode = declareHolders(resource);
          resource.statement = js.Block(holderCode.statements);
          break;
        case DeferredHolderResourceKind.deferredFragment:
          updateHolders(resource);
          break;
      }
    }
  }

  @override
  void finalize() {
    finalizeReferences();
    allocateResources();
  }

  @override
  void registerDeferredHolderExpression(
      String resourceName, DeferredHolderExpression node) {
    holderReferences.add(node);
  }

  @override
  void registerDeferredHolderResource(DeferredHolderResource node) {
    holderResources.add(node);
  }

  @override
  void registerDeferredHolderParameter(DeferredHolderParameter node) {
    holderParameters.add(node);
  }
}

class LegacyHolderCode {
  final List<String> activeHolders;
  final List<js.Statement> statements;
  LegacyHolderCode(this.activeHolders, this.statements);
}
