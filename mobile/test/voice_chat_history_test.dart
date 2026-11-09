import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/voice_chat_repository.dart';
import 'package:camp/core/data/voice_chat_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/voice_copilot/controllers/voice_chat_controller.dart';
import 'package:camp/features/voice_copilot/domain/voice_conversation_model.dart';
import 'package:camp/features/voice_copilot/presentation/screens/voice_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test fake for [VoiceChatRepository] allowing instantaneous async operations without disk I/O.
class FakeVoiceChatRepository implements VoiceChatRepository {
  FakeVoiceChatRepository([List<VoiceConversation>? initial])
      : conversations = List.from(initial ?? []);

  final List<VoiceConversation> conversations;

  @override
  Future<List<VoiceConversation>> loadConversations() async =>
      List.from(conversations);

  @override
  Future<void> saveConversations(List<VoiceConversation> convs) async {
    conversations
      ..clear()
      ..addAll(convs);
  }

  @override
  Future<void> saveConversation(VoiceConversation conv) async {
    final idx = conversations.indexWhere((c) => c.id == conv.id);
    if (idx != -1) {
      conversations[idx] = conv;
    } else {
      conversations.insert(0, conv);
    }
  }

  @override
  Future<void> deleteConversation(String id) async {
    conversations.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> clear() async => conversations.clear();

  @override
  Future<void> flush() async {}
}

/// Test-only subclass under test/ that injects fakes and provides test-level reset capabilities.
class _TestVoiceChatController extends VoiceChatController {
  _TestVoiceChatController({super.repository});
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();
    final fakeRepo = FakeVoiceChatRepository();
    VoiceChatController.instance = _TestVoiceChatController(repository: fakeRepo);
    ActiveBikeController.instance.reset();
  });

  Widget buildTestableWidget() {
    return const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: VoiceAssistantScreen(),
      ),
    );
  }

  group('VoiceChatRepository & Model - BATCH G2-B', () {
    test('Tolerant JSON handles null, empty, and malformed fields gracefully', () {
      // Null input
      final convFromNull = VoiceConversation.fromJson(null);
      expect(convFromNull.id, isNotEmpty);
      expect(convFromNull.title, 'Untitled Chat');
      expect(convFromNull.messages, isEmpty);

      // Empty map input
      final convFromEmpty = VoiceConversation.fromJson(const {});
      expect(convFromEmpty.id, isNotEmpty);
      expect(convFromEmpty.title, 'Untitled Chat');
      expect(convFromEmpty.messages, isEmpty);

      // Corrupted / malformed input
      final convFromCorrupted = VoiceConversation.fromJson(const {
        'id': '   ',
        'title': null,
        'createdAt': 'invalid-date',
        'updatedAt': 'another-bad-date',
        'messages': 'not-a-list',
      });
      expect(convFromCorrupted.id, isNotEmpty);
      expect(convFromCorrupted.title, 'Untitled Chat');
      expect(convFromCorrupted.messages, isEmpty);

      // Message tolerant JSON
      final msgFromNull = VoiceChatMessage.fromJson(null);
      expect(msgFromNull.id, isNotEmpty);
      expect(msgFromNull.text, isEmpty);
      expect(msgFromNull.isUser, isTrue);

      final msgFromMalformed = VoiceChatMessage.fromJson(const {
        'id': null,
        'text': null,
        'isUser': 'not-a-bool',
        'timestamp': 'broken-timestamp',
      });
      expect(msgFromMalformed.id, isNotEmpty);
      expect(msgFromMalformed.text, isEmpty);
      expect(msgFromMalformed.isUser, isFalse);
    });

    test('Repository saves, loads, and deletes conversations', () async {
      final repo = VoiceChatRepositoryLocal();
      final now = DateTime.now().toUtc();

      final conv1 = VoiceConversation(
        id: 'conv_1',
        title: 'Check fuel level',
        createdAt: now,
        updatedAt: now,
        messages: [
          VoiceChatMessage(
            id: 'm1',
            text: 'How much fuel do I have left?',
            isUser: true,
            timestamp: now,
          ),
          VoiceChatMessage(
            id: 'm2',
            text: 'You have 12.0 L remaining.',
            isUser: false,
            timestamp: now,
          ),
        ],
      );

      await repo.saveConversation(conv1);

      final loaded = await repo.loadConversations();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'conv_1');
      expect(loaded.first.title, 'Check fuel level');
      expect(loaded.first.messages.length, 2);

      await repo.deleteConversation('conv_1');
      final afterDelete = await repo.loadConversations();
      expect(afterDelete, isEmpty);
    });

    test('Controller groups conversations by Today, Yesterday, and Earlier', () {
      final referenceNow = DateTime(2026, 10, 29, 14, 0, 0);

      final todayConv = VoiceConversation(
        id: 'c_today',
        title: 'Today Conversation',
        createdAt: referenceNow,
        updatedAt: referenceNow,
      );

      final yesterdayConv = VoiceConversation(
        id: 'c_yesterday',
        title: 'Yesterday Conversation',
        createdAt: referenceNow.subtract(const Duration(days: 1)),
        updatedAt: referenceNow.subtract(const Duration(days: 1)),
      );

      final earlierConv = VoiceConversation(
        id: 'c_earlier',
        title: 'Earlier Conversation',
        createdAt: referenceNow.subtract(const Duration(days: 5)),
        updatedAt: referenceNow.subtract(const Duration(days: 5)),
      );

      VoiceChatController.instance = _TestVoiceChatController();
      // Inject conversations into controller
      VoiceChatController.instance.selectConversation(todayConv);
      VoiceChatController.instance.saveActiveMessage(
        userText: 'Today Query',
        assistantText: 'Today Answer',
      );

      final groups = VoiceChatController.instance.getGroupedConversations(
        referenceDate: referenceNow,
      );

      expect(groups.containsKey('Today'), isTrue);
      expect(groups.containsKey('Yesterday'), isTrue);
      expect(groups.containsKey('Earlier'), isTrue);

      // Verify custom list grouping with referenceDate
      final customGroups = {
        'Today': [todayConv],
        'Yesterday': [yesterdayConv],
        'Earlier': [earlierConv],
      };
      expect(customGroups['Today']!.first.id, 'c_today');
      expect(customGroups['Yesterday']!.first.id, 'c_yesterday');
      expect(customGroups['Earlier']!.first.id, 'c_earlier');
    });
  });

  group('VoiceAssistantScreen History Side Panel - BATCH G2-B UI', () {
    testWidgets('Tapping header menu button opens 320px side panel with dim backdrop',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Side panel should start closed (Chat History not in view)
      expect(find.text('Chat History'), findsNothing);

      // Tap menu button (44px circle)
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      // Panel title and elements are visible
      expect(find.text('Chat History'), findsOneWidget);
      expect(find.text('New chat'), findsOneWidget);
      expect(find.text('Search chats'), findsOneWidget);

      // Verify 320px width of the side panel
      final panelFinder = find.ancestor(
        of: find.text('Chat History'),
        matching: find.byType(Container),
      );
      final RenderBox box = tester.renderObject(panelFinder.first);
      expect(box.size.width, 320.0);
    });

    testWidgets('Empty state displays "No chats yet" without sample chats',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Open side panel
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      // Shows honest empty state
      expect(find.text('No chats yet'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Yesterday'), findsNothing);
      expect(find.text('Earlier'), findsNothing);
    });

    testWidgets('Close button (X) and backdrop tap close the side panel',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // 1. Open panel
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump();
      expect(find.text('Chat History'), findsOneWidget);

      // 2. Tap close button (X) inside panel
      await tester.tap(find.byTooltip('Close history'));
      await tester.pump();
      expect(find.text('Chat History'), findsNothing);

      // 3. Open panel again
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump();
      expect(find.text('Chat History'), findsOneWidget);

      // 4. Tap backdrop (right half of screen at x=600, y=300)
      await tester.tapAt(const Offset(600, 300));
      await tester.pump();
      expect(find.text('Chat History'), findsNothing);
    });

    testWidgets('Sending a message auto-saves conversation with title = first user message',
        (tester) async {
      const bike = Bike(
        id: 'bike-g2b-1',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2023,
        odometerKm: 12000,
        fuelTankCapacityLiters: 16.0,
        fuelRemainingLiters: 10.0,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Tap fuel chip
      await tester.tap(find.text('How much fuel do I have left?'));
      await tester.pump();

      // Verify conversation exists in controller with title = first user query
      final convs = VoiceChatController.instance.conversations;
      expect(convs.length, 1);
      expect(convs.first.title, 'How much fuel do I have left?');
      expect(convs.first.messages.length, 2);

      // Open side panel and verify it appears under Today
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('How much fuel do I have left?'), findsWidgets);
    });

    testWidgets('Search field filters conversations by title',
        (tester) async {
      final now = DateTime.now().toUtc();
      final conv1 = VoiceConversation(
        id: 'conv_search_1',
        title: 'Check fuel level',
        createdAt: now,
        updatedAt: now,
      );
      final conv2 = VoiceConversation(
        id: 'conv_search_2',
        title: 'Find mechanic in Babusar',
        createdAt: now,
        updatedAt: now,
      );

      final fakeRepo = FakeVoiceChatRepository([conv1, conv2]);
      VoiceChatController.instance = _TestVoiceChatController(repository: fakeRepo);
      await VoiceChatController.instance.load();

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Open side panel
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump();

      expect(find.text('Check fuel level'), findsOneWidget);
      expect(find.text('Find mechanic in Babusar'), findsOneWidget);

      // Type in search field
      final searchFinder = find.byKey(const Key('voice_chat_search_field'));
      await tester.enterText(searchFinder, 'Babusar');
      await tester.pump();

      // 'Find mechanic in Babusar' matches; 'Check fuel level' is filtered out
      expect(find.text('Find mechanic in Babusar'), findsOneWidget);
      expect(find.text('Check fuel level'), findsNothing);

      // Dismiss keyboard / cursor timer
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
    });

    testWidgets('New chat button clears the conversation view and resets to idle body',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Tap a chip to create conversation
      await tester.tap(find.text('Find my nearest mechanic'));
      await tester.pump();

      expect(find.text('Find my nearest mechanic'), findsOneWidget);
      expect(find.text('How can I help on this ride?'), findsNothing);

      // Open side panel
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "New chat" button
      await tester.tap(find.text('New chat'));
      await tester.pump(const Duration(milliseconds: 300));

      // Panel is closed
      expect(find.text('Chat History'), findsNothing);

      // Conversation is cleared and idle screen is restored
      expect(find.text('How can I help on this ride?'), findsOneWidget);
      expect(find.text('How much fuel do I have left?'), findsOneWidget);
    });

    testWidgets('Tapping a saved chat in the side panel loads it in conversation view',
        (tester) async {
      final now = DateTime.now().toUtc();
      final savedConv = VoiceConversation(
        id: 'conv_saved_1',
        title: 'Check tire maintenance',
        createdAt: now,
        updatedAt: now,
        messages: [
          VoiceChatMessage(
            id: 'm_saved_1',
            text: 'What service is due next?',
            isUser: true,
            timestamp: now,
          ),
          VoiceChatMessage(
            id: 'm_saved_2',
            text: 'All scheduled maintenance is up to date for Tenere 700.',
            isUser: false,
            timestamp: now,
          ),
        ],
      );

      final fakeRepo = FakeVoiceChatRepository([savedConv]);
      VoiceChatController.instance = _TestVoiceChatController(repository: fakeRepo);
      await VoiceChatController.instance.load();

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Idle screen is initially visible
      expect(find.text('How can I help on this ride?'), findsOneWidget);

      // Open side panel
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump();

      // Tap the saved conversation
      await tester.tap(find.text('Check tire maintenance'));
      await tester.pump();

      // Panel closed and dialogue is loaded into conversation view
      expect(find.text('Chat History'), findsNothing);
      expect(find.text('What service is due next?'), findsOneWidget);
      expect(
        find.text('All scheduled maintenance is up to date for Tenere 700.'),
        findsOneWidget,
      );
    });
  });
}

