import 'concert_repository.dart';
import 'local_json_concert_repository.dart';

ConcertRepository createDefaultConcertRepository() =>
    LocalJsonConcertRepository();
