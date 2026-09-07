part of '../auth_pages.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    
    this.admin = false,this.initialEmail = '',
    this.isAdmin = false,
    this.role,
  });

  final String initialEmail;
  final bool admin;
  final bool isAdmin;
  final String? role;

  bool get adminMode => admin || isAdmin || role == 'admin';

  @override
  State<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState
    extends State<ForgotPasswordPage> {
  late final TextEditingController email;
  final a1 = TextEditingController();
  final a2 = TextEditingController();
  
  bool busy = false;
  int step = 1; // 1: Email, 2: Method Select, 3: Questions
  Map<String, dynamic>? profile;
  String resetMethod = 'email'; // 'email' or 'questions'

  @override
  void initState() {
    super.initState();
    email = TextEditingController(text: widget.initialEmail);
  }

  Future<void> checkEmail() async {
    final address = email.text.trim().toLowerCase();
    if (address.isEmpty || !isValidEmail(address)) {
      showMessage(context, 'Enter a valid email address.', error: true);
      return;
    }

    setState(() => busy = true);
    try {
      final data = await AppServices.findProfileByEmail(address);
      if (data == null) {
        throw Exception('No account found for this email address in our system.');
      }
      
      profile = data;
      setState(() => step = 2);
    } catch (e) {
      if (mounted) {
        showMessage(
          context, 
          e.toString().replaceFirst('Exception: ', ''), 
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyQuestions() async {
    final questions = profile?['securityQuestions'] as List?;
    if (questions == null || questions.length < 2) {
      showMessage(context, 'This account does not have security questions set up.', error: true);
      return;
    }

    final ans1 = a1.text.trim().toLowerCase();
    final ans2 = a2.text.trim().toLowerCase();

    if (ans1.isEmpty || ans2.isEmpty) {
      showMessage(context, 'Please answer both questions.', error: true);
      return;
    }

    final correctAns1 = questions[0]['answer']?.toString().toLowerCase();
    final correctAns2 = questions[1]['answer']?.toString().toLowerCase();

    if (ans1 == correctAns1 && ans2 == correctAns2) {
      // Identity Verified! 
      // Move to "New Password" step
      setState(() => step = 4);
    } else {
      if (mounted) showMessage(context, 'Security answers are incorrect.', error: true);
    }
  }

  Future<void> sendResetLink() async {
    final address = email.text.trim().toLowerCase();
    setState(() => busy = true);

    try {
      await AppServices.auth.sendPasswordResetEmail(email: address);

      if (!mounted) return;
      showGlobalNotice(
        title: 'Email Sent',
        message: 'A password reset link has been sent to $address. Please check your inbox and follow the instructions.',
        buttonText: 'OK',
        onConfirm: () => Navigator.pop(context),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      var message = 'Unable to send the reset email.';
      if (error.code == 'user-not-found') {
        message = 'No account was found for this email address.';
      } else if (error.code == 'invalid-email') {
        message = 'The email address is invalid.';
      } else if (error.message != null &&
          error.message!.trim().isNotEmpty) {
        message = error.message!;
      }

      showMessage(context, message, error: true);
    } catch (error) {
      if (!mounted) return;
      showMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    a1.dispose();
    a2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminMode = widget.adminMode;

    return Scaffold(
      backgroundColor: adminMode
          ? ExplorerColors.companionBackground
          : ExplorerColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (step > 1) {
              setState(() => step = 1);
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Forgot Password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ExplorerCard(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return switch (step) {
      2 => _buildMethodSelect(),
      3 => _buildQuestionsStep(),
      4 => _buildNewPasswordStep(),
      _ => _buildEmailStep(),
    };
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.adminMode) ...[
          const Center(child: ExplorerBrand()),
          const SizedBox(height: 20),
        ],
        _iconHeader(Icons.mark_email_read_outlined),
        const Text(
          'Reset your password',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ExplorerColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the email address registered with MyHeritage Explorer.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ExplorerColors.muted, height: 1.45),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: busy ? null : checkEmail,
          child: Text(busy ? 'Checking...' : 'Continue'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }

  Widget _buildMethodSelect() {
    final questions = profile?['securityQuestions'] as List?;
    final hasQuestions = questions != null && questions.length >= 2;

    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _iconHeader(Icons.security_outlined),
        const Text(
          'Select Reset Method',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ExplorerColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how you would like to verify your identity to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ExplorerColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: ExplorerColors.border),
          ),
          leading: const Icon(Icons.alternate_email, color: ExplorerColors.navy),
          title: const Text('Email Link'),
          subtitle: const Text('Send a reset link to your inbox'),
          onTap: () => sendResetLink(),
        ),
        const SizedBox(height: 12),
        ListTile(
          enabled: hasQuestions,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: hasQuestions ? ExplorerColors.border : Colors.grey.shade200,
            ),
          ),
          leading: Icon(
            Icons.quiz_outlined, 
            color: hasQuestions ? ExplorerColors.navy : Colors.grey.shade400,
          ),
          title: Text(
            'Security Questions',
            style: TextStyle(
              color: hasQuestions ? Colors.black : Colors.grey.shade500,
              fontWeight: hasQuestions ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            hasQuestions 
                ? 'Verify using your preset answers' 
                : 'No security questions found for this account',
            style: TextStyle(
              fontSize: 12,
              color: hasQuestions ? ExplorerColors.muted : Colors.grey.shade400,
            ),
          ),
          onTap: hasQuestions ? () => setState(() => step = 3) : null,
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() => step = 1),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  Widget _buildQuestionsStep() {
    final questions = profile?['securityQuestions'] as List?;
    final qText1 = questions != null && questions.isNotEmpty 
        ? questions[0]['question'] 
        : 'Question 1 (Not set)';
    final qText2 = questions != null && questions.length > 1 
        ? questions[1]['question'] 
        : 'Question 2 (Not set)';

    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _iconHeader(Icons.fact_check_outlined),
        const Text(
          'Verify Identity',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ExplorerColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Answer the security questions you set during registration.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ExplorerColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Text(
          qText1,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: a1,
          decoration: const InputDecoration(hintText: 'Answer 1'),
        ),
        const SizedBox(height: 20),
        Text(
          qText2,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: a2,
          decoration: const InputDecoration(hintText: 'Answer 2'),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: busy ? null : verifyQuestions,
          child: Text(busy ? 'Verifying...' : 'Verify Identity'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => step = 2),
          child: const Text('Back to methods'),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      key: const ValueKey('step4'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _iconHeader(Icons.lock_reset_outlined),
        const Text(
          'Reset Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ExplorerColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your identity has been verified! For your security, please use the reset link sent to your email to set a new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ExplorerColors.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: busy ? null : sendResetLink,
          child: Text(busy ? 'Sending...' : 'Send Reset Link'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Return to Login'),
        ),
      ],
    );
  }

  Widget _iconHeader(IconData icon) {
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        color: ExplorerColors.navySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: ExplorerColors.navy, size: 28),
    );
  }
}

