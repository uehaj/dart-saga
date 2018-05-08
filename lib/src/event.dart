import "dart:isolate";

class Event {}

class ForkedEvent {
  SendPort parent;
  SendPort child;
}
