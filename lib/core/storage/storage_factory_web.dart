import 'concert_repository.dart';
import 'web_local_storage_concert_repository.dart';

ConcertRepository createDefaultConcertRepository() =>
    WebLocalStorageConcertRepository();
