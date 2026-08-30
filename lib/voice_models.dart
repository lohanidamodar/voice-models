/// A shared, on-disk store for speech models.
///
/// Several apps fetch a model once and all find it afterwards, because these
/// are hundreds of megabytes each and identical between them. Every model
/// carries its licence, and that licence is shown before anything is
/// downloaded — weights are not ours to relicense, and some of the best ones
/// are not published under an open-source licence at all.
library;

export 'src/catalog.dart';
export 'src/licence.dart';
export 'src/paths.dart';
export 'src/store.dart';
