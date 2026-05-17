import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'agency_details_screen.dart';
import 'create_agency_screen.dart';

class AgenciesScreen extends StatelessWidget {
  final String search;

  const AgenciesScreen({super.key, required this.search});

  @override
  Widget build(BuildContext context) {

    final agencies = FirebaseFirestore.instance.collection('agencies');

    return StreamBuilder<QuerySnapshot>(
      stream: agencies.snapshots(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs;

        /// SEARCH FILTER
        if (search.isNotEmpty) {
          docs = docs.where((d) {
            final name = (d['name'] ?? '').toString().toLowerCase();
            return name.contains(search.toLowerCase());
          }).toList();
        }

        return Column(
          children: [

            /// ADD AGENCY BUTTON
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text("إضافة وكالة"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateAgencyScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            /// GRID VIEW
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 10),
                itemCount: docs.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // ✅ 4 cards per row
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9, // makes cards taller so text fits
                ),
                itemBuilder: (context, index) {

                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final name = data['name'] ?? '';
                  final referral = data['referralCode'] ?? '';
                  final drivers = data['totalDrivers'] ?? 0;
                  final wallet = data['walletBalance'] ?? 0;
                  final commission = data['commissionPercent'] ?? 0;

                  return _AgencyCard(
                    agencyId: doc.id,
                    name: name,
                    referral: referral,
                    drivers: drivers,
                    wallet: wallet,
                    commission: commission,
                    data: data,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////////
/// AGENCY CARD (ANIMATED)
////////////////////////////////////////////////////////////////

class _AgencyCard extends StatefulWidget {

  final String agencyId;
  final String name;
  final String referral;
  final int drivers;
  final num wallet;
  final num commission;
  final Map<String, dynamic> data;

  const _AgencyCard({
    required this.agencyId,
    required this.name,
    required this.referral,
    required this.drivers,
    required this.wallet,
    required this.commission,
    required this.data,
  });

  @override
  State<_AgencyCard> createState() => _AgencyCardState();
}

class _AgencyCardState extends State<_AgencyCard>
    with SingleTickerProviderStateMixin {

  double scale = 1;

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTapDown: (_) => setState(() => scale = 0.96),
      onTapUp: (_) => setState(() => scale = 1),
      onTapCancel: () => setState(() => scale = 1),

      onTap: () {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AgencyDetailsScreen(
              agencyId: widget.agencyId,
              agencyData: widget.data,
            ),
          ),
        );
      },

      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: scale,

        child: Container(
          padding: const EdgeInsets.all(10),

          decoration: BoxDecoration(

            gradient: LinearGradient(
              colors: [
                Colors.red.shade700,
                Colors.red.shade900,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            borderRadius: BorderRadius.circular(18),

            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// TOP ROW
              Row(
                children: [

                  const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 20,
                  ),

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(
                      "${widget.commission}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 14),

              /// AGENCY NAME
              Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                "كود الإحالة: ${widget.referral}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              /// DRIVERS
              Row(
                children: [

                  const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 18,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    "${widget.drivers} سائق",
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              /// WALLET
              Row(
                children: [

                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 18,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    "${widget.wallet} جنيه",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}