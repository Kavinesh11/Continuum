class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String platform;
  final String zone;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.platform,
    required this.zone,
  });

  factory UserModel.mock() {
    return UserModel(
      id: 'SWG-9284-912',
      fullName: 'John Doe',
      email: 'john.doe@gigworker.com',
      platform: 'Swiggy',
      zone: 'Bangalore South - HSR',
    );
  }
}
