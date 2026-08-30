/// The terms a model is published under.
///
/// Carried as data rather than prose in a README because it has to be shown at
/// the moment it matters — before anything is downloaded. Weights are not ours
/// to relicense, and several of the good ones are not under an OSI licence at
/// all, so "MIT app" says nothing about the model it fetches.
class ModelLicence {
  const ModelLicence({
    required this.name,
    required this.url,
    this.attribution,
    this.isOsiApproved = true,
    this.notes,
  });

  /// SPDX identifier where one exists, otherwise the publisher's own name for
  /// it — `CC-BY-4.0`, or `FunASR Model Open Source License Agreement v1.1`.
  final String name;

  /// Where to read the actual terms.
  final String url;

  /// The credit line a redistributor owes, when the licence requires one.
  ///
  /// CC-BY is the common case: free to use, provided the author is named.
  final String? attribution;

  /// False for publisher-specific terms. Not a judgement — a signal that the
  /// licence has to be read rather than recognised.
  final bool isOsiApproved;

  /// Anything a user should know before agreeing, in one sentence.
  final String? notes;

  bool get requiresAttribution => attribution != null;

  /// A single line for a console prompt or a settings screen.
  String get summary => [
        name,
        if (!isOsiApproved) '(publisher terms — read them)',
        if (requiresAttribution) '(attribution required)',
      ].join(' ');

  static const ccBy40 = ModelLicence(
    name: 'CC-BY-4.0',
    url: 'https://creativecommons.org/licenses/by/4.0/',
    attribution: 'Model by NVIDIA, licensed under CC-BY-4.0.',
    notes: 'Free to use commercially, provided NVIDIA is credited.',
  );

  static const mit = ModelLicence(
    name: 'MIT',
    url: 'https://opensource.org/license/mit',
  );

  static const apache20 = ModelLicence(
    name: 'Apache-2.0',
    url: 'https://www.apache.org/licenses/LICENSE-2.0',
  );

  /// SenseVoice and the rest of the FunASR family.
  ///
  /// Not an OSI licence. It permits use, modification and sharing, and adds
  /// conditions of its own — which is exactly why it is surfaced rather than
  /// summarised away.
  static const funAsr = ModelLicence(
    name: 'FunASR Model Open Source License Agreement v1.1',
    url: 'https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE',
    isOsiApproved: false,
    notes: "Alibaba's own terms, not an OSI licence. Read them before "
        'shipping anything built on this model.',
  );
}
