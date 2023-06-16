// ignore: public_member_api_docs
bool isFromServer(String url) => RegExp(
      r'^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]'
      r'[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$',
    ).hasMatch(url);
