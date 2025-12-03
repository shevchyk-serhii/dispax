import 'package:flutter/material.dart';
import '../../screens/create_ride_screen.dart';

class SecretaryDashboard extends StatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [_CreateRidesTab(), _ManageClientsTab(), _ReportsTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Create Ride',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class _CreateRidesTab extends StatelessWidget {
  const _CreateRidesTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Ride'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade600, Colors.grey.shade50],
            stops: const [0.0, 0.15],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 64,
                        color: Colors.purple[600],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Create New Ride',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Book rides for your clients with flight information and airport transfer details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const CreateRideScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Start Creating'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStatCard(
                        'Today\'s Rides',
                        '12',
                        Icons.today,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildQuickStatCard(
                        'This Week',
                        '47',
                        Icons.date_range,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageClientsTab extends StatelessWidget {
  const _ManageClientsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Client Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Client list and account management',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Reports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Statistics and ride reports',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
