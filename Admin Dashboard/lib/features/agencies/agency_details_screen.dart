import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AgencyDetailsScreen extends StatelessWidget {
  final String agencyId;
  final Map<String, dynamic> agencyData;

  const AgencyDetailsScreen({
    super.key,
    required this.agencyId,
    required this.agencyData,
  });

  @override
  Widget build(BuildContext context) {

    final driversQuery = FirebaseFirestore.instance
        .collection('drivers')
        .where('agencyId', isEqualTo: agencyId);

    return Scaffold(
      appBar: AppBar(
        title: Text(agencyData['name'] ?? "Agency"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            /// AGENCY INFO CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Referral Code"),
                        Text(agencyData['referralCode'] ?? ""),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Drivers"),
                        Text("${agencyData['totalDrivers'] ?? 0}"),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Revenue"),
                        Text("${agencyData['totalRevenue'] ?? 0}"),
                      ],
                    ),

                  ],
                ),
              ),
            ),

            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('agencies')
                  .doc(agencyId)
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) return SizedBox();

                final data = snapshot.data!.data() as Map<String, dynamic>;

                final balance = data['walletBalance'] ?? 0;
                final withdrawn = data['totalWithdrawn'] ?? 0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [

                        const Text(
                          "Agency Wallet",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Current Balance"),
                            Text("$balance EGP"),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Withdrawn"),
                            Text("$withdrawn EGP"),
                          ],
                        ),

                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rides')
                  .where('agencyId', isEqualTo: agencyId)
                  .where('status', isEqualTo: 'completed')
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final rides = snapshot.data!.docs;

                double totalFare = 0;

                for (var ride in rides) {
                  final data = ride.data() as Map<String, dynamic>;
                  totalFare += (data['fare'] ?? 0);
                }

                final percent = agencyData['commissionPercent'] ?? 0;

                final agencyRevenue = totalFare * percent / 100;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [

                        const Text(
                          "Agency Revenue",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Trips Revenue"),
                            Text("${totalFare.toStringAsFixed(2)} EGP"),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Agency Commission"),
                            Text("${agencyRevenue.toStringAsFixed(2)} EGP"),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Drivers",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            /// DRIVERS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: driversQuery.snapshots(),
                builder: (context, snapshot) {

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final drivers = snapshot.data!.docs;

                  if (drivers.isEmpty) {
                    return const Center(
                      child: Text("No drivers in this agency"),
                    );
                  }

                  return ListView.builder(
                    itemCount: drivers.length,
                    itemBuilder: (context, index) {

                      final data =
                      drivers[index].data() as Map<String, dynamic>;

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(data['name'] ?? ""),
                          subtitle: Text(data['phone'] ?? ""),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}