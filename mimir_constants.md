Website for constants: https://docs.mayaprotocol.com/deep-dive/how-it-works/constants-and-mimir
Website for endpoints: https://mayanode.mayachain.info/mayachain/doc
## int_64_values

#### AffiliateFeeTickGranularity: 100
Determines the granularity (or “step” size) used for applying affiliate fees. A larger number makes fee adjustments coarser, meaning the protocol can only change affiliate fees in bigger increments. This helps limit frequent, minute changes in affiliate fee rates. Conversely, a smaller number provides finer control over fee calibrations.

---

#### AllowWideBlame: 0
Indicates whether the system is allowed to assign “wider blame” to multiple participants for a failed TSS (Threshold Signature Scheme) signing event. When set to `0` (disabled), the protocol is more conservative, typically blaming only nodes that definitively failed their signing duties. If enabled, partial or ambiguous failures could lead to broader blaming—useful if the protocol wants to ensure accountability even in uncertain scenarios.

---

#### AsgardSize: 40
Controls the maximum or target number of **Asgard vaults**. Asgard vaults are the network’s main pooled vaults, holding user and protocol assets. Having more Asgard vaults spreads risk—compromising one vault does not jeopardize all funds—and can improve parallel transaction processing. However, each additional vault increases operational complexity and overhead, so this parameter balances security and efficiency.

---

#### BadValidatorRate: 43200
Specifies the block window (approximately 3 days at a 6-second block time) during which slash points accumulate to assess if a validator is “bad.” The protocol monitors node misbehaviors—such as failing to sign transactions, missing block observations, or other rule violations—and adds slash points within this timeframe. Persistently high slash points can lead to ejection or severe penalties.

---

#### BadValidatorRedline: 3
Indicates how many critical failures (or how many times a node can exceed certain slash point thresholds) are tolerated before the protocol formally marks it as a “bad validator.” Crossing this redline may cause the validator to be force-churned out, jailed for an extended period, or otherwise restricted from participating in the network.

---

#### BlocksPerDay: 14400
The protocol’s estimate of how many blocks fit into a 24-hour day. Assuming a 6-second block time, 14,400 blocks × 6 seconds = 86,400 seconds, which is exactly one day. This value is used for day-based calculations, such as daily emissions, daily yield payouts, or time-locked actions.

---

#### BlocksPerYear: 5256000
An estimate of how many blocks occur in one calendar year. With a 6-second block time, 5,256,000 blocks × 6 seconds = 31,536,000 seconds, roughly 365 days. This value is key for annualized calculations, like yearly inflation or annual percentage yields (APYs).

---

#### CACAOPoolDepositMaturityBlocks: 14400
Defines how many blocks must pass (about 1 day) before a deposit into the Cacao pool (Cacao is Maya’s native asset) is considered “mature.” This prevents immediate withdrawals or manipulations that exploit pending deposits. The protocol can apply certain yield calculations or privileges only after deposits have “fully matured.”

---

#### CACAOPoolEnabled: 0
A binary flag indicating whether Cacao-based pools have special behaviors enabled (e.g., unique deposit rules, incentives, or priority for Maya’s native token). A value of `0` means these specialized Cacao pool features are currently disabled, relying on standard pool logic.

---

#### ChurnInterval: 43200
The number of blocks (about 3 days) between vault churns. **Churning** is the process of rotating membership in Asgard vaults and refreshing associated TSS keys. This routine ensures no single group of nodes stays responsible for network funds indefinitely, distributing trust and minimizing inside threats.

---

#### ChurnRetryInterval: 720
If a churn attempt fails—for example, if not enough nodes sign off on the new vault addresses—the network waits 720 blocks (about 1.2 hours) before retrying. This pause allows nodes to sync, diagnose potential issues, and avoid spamming repeated churn attempts that keep failing.

---

#### DesiredValidatorSet: 100
Represents the protocol’s ideal number of active validators. A robust validator set helps decentralize the network and increases fault tolerance. However, more validators can dilute rewards and increase overhead. Striking the right number ensures security without excessive complexity.

---

#### DoubleSignMaxAge: 23
Maximum block age for evidence of “double-signing.” If a validator signs multiple conflicting blocks or transactions within this block window, they can be slashed severely. Beyond 23 blocks, evidence of double-signing might be considered stale, preventing the protocol from punishing extremely old misbehaviors that could be disputed or due to chain reorgs.

---

#### EVMDisableContractWhitelist: 0
Indicates whether the EVM module on Maya enforces a contract whitelist. With a `0` value, the whitelist is enforced (only known/trusted contracts can be interacted with). Setting this to `1` would disable the whitelist, allowing any address or contract to be used—which increases flexibility but also risk.

---

#### FailKeygenSlashPoints: 720
The number of slash points a validator receives if they fail to participate in a **key generation** event (i.e., TSS keygen for a new Asgard or Yggdrasil vault). Missing keygen is a severe offense because it blocks the protocol from creating secure vault addresses. Accumulating enough slash points leads to jail or ejection.

---

#### FailKeysignSlashPoints: 2
Slash points assigned to a validator for failing to sign outbound transactions (keysign events). This penalty is smaller than failing keygen because missing a single outbound transaction is less impactful than blocking the creation of a new vault. However, repeated failures can still add up to significant penalties.

---

#### ForgiveSlashPeriod: 17280
The number of blocks (about 1.2 days) after which slash points begin to “forgive” or decay if no further infractions occur. This helps differentiate between a node that made a one-time mistake vs. one that repeatedly misbehaves. Over time, a well-behaved node’s slash points trend back toward zero.

---

#### FullImpLossProtectionBlocks: 2160000
The number of blocks over which liquidity providers (LPs) gain **full impermanent loss (IL) protection.** Typically, after this period (around 150 days at 6s/block), the protocol compensates LPs fully for any impermanent loss they might have incurred, encouraging longer-term liquidity provision rather than short-term speculation.

---

#### FullImpLossProtectionBlocksTimes4: 6480000
An extended period—four times longer than the standard schedule—for protocols or scenarios that prefer a more gradual approach to providing impermanent loss protection. This could be an alternative policy or used under certain conditions where the protocol wants to slow the rate at which IL coverage vests.

---

#### FundMigrationInterval: 360
How often (in blocks) the protocol attempts to redistribute or migrate funds between vaults. This might be done to rebalance Yggdrasil vaults, or to move assets from older vaults to newly churned Asgard vaults. A smaller interval means more frequent but smaller migrations; a larger interval consolidates the movements into more substantial but less frequent operations.

---

#### InflationFormulaMulValue: 4000
A multiplier within the protocol’s **inflation formula**, used to calculate how many new tokens (Cacao/RUNE) the system mints over time. This pairs with `InflationFormulaSumValue` to determine block-by-block or daily inflation rates, ensuring the network can fund rewards without inflating uncontrollably.

---

#### InflationFormulaSumValue: 100
The additive constant in the inflation formula. When combined with `InflationFormulaMulValue` and the network’s target inflation or bonding needs, this yields a dynamic issuance schedule. The sum value helps fine-tune the result, ensuring inflation does not drop too low or spike too high.

---

#### InflationPercentageThreshold: 9000
An upper limit (in basis points) on the acceptable inflation rate. If the protocol detects inflation nearing or exceeding this threshold (90%), it can trigger protective measures—like adjusting node rewards, modifying bond requirements, or restricting new liquidity—to keep monetary expansion under control.

---

#### InflationPoolPercentage: 50
Indicates the portion of newly minted tokens allocated to liquidity pools. If this is set to 50, half of the minted supply might go toward LP rewards, while the remainder could go to node operators, reserves, or protocol funds. This ensures consistent incentives for liquidity providers while also supporting other network participants.

---

#### JailTimeKeygen: 4320
Number of blocks (about half a day) a validator is jailed if they fail to participate in a TSS key generation. During this jail period, the node cannot earn rewards or join active signing. This penalty is more severe than failing a keysign because an incomplete keygen stalls the creation of entire vault addresses, which is critical for network security.

---

#### JailTimeKeysign: 60
Number of blocks (about 6 minutes) a validator is jailed if they fail to sign during a TSS keysign event. While disruptive, missing a single outbound transaction is less catastrophic than blocking new vault creation, hence the significantly shorter jail time compared to keygen failures.

---

#### KillSwitchDuration: 0
Specifies how many blocks must pass after a kill switch is triggered before the chain is forcibly halted (or a similar emergency measure). A value of `0` means the kill switch mechanism is not active. If set, this would give the network a grace period (e.g., 500 blocks) to finalize critical operations before shutting down.

---

#### KillSwitchStart: 0
The block at which a kill switch countdown begins. `0` indicates no kill switch has been scheduled. If set to a future block, once reached, the protocol triggers the countdown determined by `KillSwitchDuration`.

---

#### LackOfObservationPenalty: 2
Slash points applied if a validator fails to observe inbound transactions. Nodes must watch the chain for deposits (inbound txes) to validate them; failing to do so can delay user funds from appearing in vaults and degrade the user experience. This penalty helps ensure each validator actively monitors the network.

---

#### LiquidityLockUpBlocks: 0
Number of blocks that newly added liquidity is locked. If set to `0`, providers can freely remove liquidity right away. Lock-ups can reduce quick in-and-out liquidity "gaming" or “pool hopping,” so some protocols set this to a non-zero value to encourage longer-term liquidity stability.

---

#### LowBondValidatorRate: 43200
Similar to `BadValidatorRate`, this parameter tracks how frequently the protocol checks for validators whose bond has dropped below a required threshold. If a node’s bond is too low, it may be at higher risk for misbehavior (less skin in the game). Exceeding certain thresholds triggers warnings or ejections.

---

#### MAYANameGracePeriodBlocks: 432000
A grace period (around 30 days at 6s/block) for expired Maya Name Service (TNS) registrations. If a name expires, its owner has this buffer to renew without losing rights. After that, the name might become available for others to claim.

---

#### MaxAffiliateFeeBasisPoints: 500
The maximum affiliate fee (in basis points) that a swap can carry. `500` basis points = 5%. This parameter ensures affiliates (e.g., referrers) cannot set exorbitant fees and exploit users. It protects swap participants from hidden or overly large fee structures.

---

#### MaxAvailablePools: 100
The maximum number of liquidity pools the protocol will allow to be active at once. Restricting the total pool count can concentrate liquidity in fewer pools, improving overall depth and swap efficiency. But it also means niche assets might be excluded if the protocol is near capacity.

---

#### MaxBondProviders: 2
The maximum number of addresses that can jointly supply a single node’s bond. This feature (bond providers) lets multiple parties co-bond a validator, sharing rewards and risk. Limiting it to 2 helps keep the arrangement simple and prevents excessively fragmented bond ownership.

---

#### MaxNodeToChurnOutForLowVersion: 1
Specifies how many nodes the protocol can remove (churn out) at once for running an outdated or incompatible software version. Limiting this to `1` prevents a sudden exodus of multiple nodes that could compromise security or liveness. The protocol thus nudges upgrades gradually.

---

#### MaxOutboundAttempts: 0
A cap on how many times the network will attempt sending an outbound transaction to an external chain (e.g., Bitcoin, Ethereum). If `0`, it may default to protocol-coded logic or “unlimited tries.” Setting a non-zero value prevents indefinite retries in cases of network failure or incorrectly specified transactions.

---

#### MaxOutboundFeeMultiplierBasisPoints: 30000
The maximum multiplier (in basis points) that can be applied to the base outbound fee. `30000` basis points = 300%. This is used when external chain gas fees spike or the network experiences congestion, allowing the protocol to pay higher fees to ensure timely confirmation.

---

#### MaxSlashRatio: 25
The maximum fraction (as a percent) of a node’s total bond that can be slashed in one event or cumulatively within a given timeframe. `25` means up to 25% of the bond can be lost, protecting node operators from a complete wipeout while still punishing severe misbehavior.

---

#### MaxSwapsPerBlock: 100
The maximum number of user swaps processed in a single block. This guard rails the protocol against spam or excessive block load. If demand is high, swaps may queue, but it preserves block efficiency and helps avoid chain congestion.

---

#### MaxSynthPerAssetDepth: 2500
Defines a ratio (in basis points) limiting how much of a single pool’s asset depth can be converted into synthetic assets (“synths”). `2500` basis points = 25%. If a pool has 1,000 RUNE in total, only 250 RUNE worth of synths can exist. This helps mitigate risk if synths become too large a portion of the pool.

---

#### MaxSynthPerPoolDepth: 1700
Another ratio (17%) limiting overall synth depth across the network or on a per-pool basis. It works similarly to `MaxSynthPerAssetDepth` but might be applied more globally. Prevents oversaturation of synthetic liquidity relative to real pool depth.

"Synth_supply / balance_asset >= 17% then it’s above the limit"--Aaluxx

---

#### MaxSynthsForSaversYield: 1500
The maximum ratio (15%) of synthetics relative to real asset depth that still qualifies for savers’ yield. If the pool surpasses this threshold in synth usage, new savers might not earn yield to avoid overstretching the system’s liquidity coverage.

---

#### MaxTxOutOffset: 720
The furthest future block offset an outbound transaction can be scheduled for. Sometimes the protocol distributes large outbounds over many blocks to smooth out spikes. `720` (about 2 hours) ensures outbounds won’t be pushed too far but still offers enough flexibility for scheduling.

---

#### MayaFundPerc: 10
The percentage of fees or rewards allocated to the Maya Protocol’s treasury or development fund. `10` = 10%. This fund may cover operational costs, community grants, or further development, ensuring the protocol can sustain itself long-term.

---

#### MinOutboundFeeMultiplierBasisPoints: 15000
The lower bound for outbound fee multipliers. `15000` basis points = 150%. If network or chain conditions are minimal, the protocol still ensures it doesn’t pay less than 1.5× the base fee—helpful in maintaining consistent transaction confirmations.

---

#### MinRuneForMayaFundDist: 10000000000
Minimum RUNE threshold for distributing to the Maya Fund. Typically `1e10` suggests 100 RUNE at 8 decimals. If the available sum is below this threshold, the protocol might skip or defer distribution to avoid micro allocations.

---

#### MinRunePoolDepth: 100000000000000
The minimum required pool depth (in RUNE units) before certain operations (like enabling yield or bridging) are allowed. This ensures pools have a robust liquidity baseline, preventing unscrupulous actors from manipulating near-empty pools.

---

#### MinSlashPointsForBadValidator: 100
If a validator accrues at least 100 slash points (within the relevant window), the network regards them as “bad.” This threshold triggers potential ejection, jailing, or forced bond forfeiture, maintaining high standards for validator performance.

---

#### MinSwapsPerBlock: 10
Ensures that at least 10 swaps can be processed each block if there is demand. This helps prevent a scenario where the protocol artificially throttles swaps to nearly zero (which could happen under certain load or scheduling constraints). It balances user experience by guaranteeing some throughput.

---

#### MinTxOutVolumeThreshold: 10000000000000
A minimum outbound volume in RUNE units required to trigger certain events or thresholds (like adjusting fees, or evaluating block space usage). Below this level, the protocol may consider the outbound activity too small to warrant adjustments.

---

#### MinimumBondInRune: 100000000000000
The absolute lowest bond (in RUNE units) a validator must post to join the active set. Ensures that each node has substantial economic backing, aligning incentives (they lose more if they misbehave).

---

#### MinimumL1OutboundFeeUSD: 1
An absolute minimum outbound fee in USD terms (converted to RUNE or another gas asset) for L1 transactions. This prevents zero-fee anomalies or underpayment, ensuring cross-chain transfers remain secure and final.

---

#### MinimumNodesForBFT: 4
The fewest number of validators needed to maintain Byzantine Fault Tolerance in a practical sense. If the active set falls below 4, the network can’t guarantee security against malicious collusion or node failures.

---

#### MinimumNodesForYggdrasil: 6
Specifies how many active nodes are needed to enable the use of Yggdrasil vaults. Below this count, the network may disable Yggdrasil usage to avoid too much trust in a small set of vault operators.

---

#### MinimumPoolLiquidityFee: 0
A floor on the protocol’s liquidity fee. `0` means no enforced minimum. If the protocol wanted to ensure a baseline fee for all pool transactions, it could set a higher value.

---

#### MultipleAffiliatesMaxCount: 5
Allows up to five different affiliate addresses in a single swap. This can split referral fees among multiple parties. More than five might complicate the distribution or open up spam scenarios.

---

#### NativeTransactionFee: 2000000000
The base fee (in smallest RUNE/Cacao units) for a native transaction. For instance, if RUNE has 8 decimals, `2,000,000,000` could represent 20 RUNE cents or some fraction. This is the on-chain cost for simple transfers within Maya’s native environment.

---

#### NodeOperatorFee: 3300
Indicates the share of rewards or fees (in basis points) going to node operators. `3300` = 33%. This ensures node operators are fairly compensated for providing security and infrastructure, while the remainder goes to liquidity providers or the protocol reserve.

---

#### NodePauseChainBlocks: 720
If a sufficient quorum of node operators decides to pause the chain (due to an emergency or exploit), the chain remains paused for at least 720 blocks (about 2 hours). After that period, it can automatically attempt to resume or require another governance action.

---

#### ObservationDelayFlexibility: 10
A buffer (in blocks) granting nodes extra leeway to observe inbound transactions. If set too low, even small network hiccups could falsely mark nodes as offline. This flexibility helps account for block propagation delays or minor network latency.

---

#### ObserveSlashPoints: 1
The slash points a validator receives for failing to observe an inbound transaction. Although small individually, repeated failures can quickly accumulate, aligning node incentives to remain reliable watchers of the chain.

---

#### OldValidatorRate: 43200
A scheduling or rate-based parameter controlling how often the protocol re-checks older validators for potential churn-out. Similar to how it rotates vaults, the network may want to cycle out very old nodes for newer ones, ensuring that all active nodes remain current and well-bonded.

---

#### OutboundTransactionFee: 2000000000
The base fee (in smallest RUNE units) for outbound transactions from Maya’s vaults to external addresses. Gas fees on external chains might be added on top, but this is the protocol’s baseline for key-sign or TSS-related outbounds.

---

#### POLBuffer: 0
A “Protocol Owned Liquidity” buffer, representing extra liquidity the protocol might keep on hand to stabilize pools or handle volatility. If `0`, the network isn’t holding extra liquidity for that purpose. A non-zero buffer can help the protocol intervene in extreme market conditions.

---

#### POLMaxNetworkDeposit: 0
The maximum deposit size the protocol can allocate to pools as protocol-owned liquidity. `0` means the feature is disabled, so the protocol doesn’t auto-deposit into pools. If enabled, the protocol might add RUNE/Cacao to deepen liquidity in strategic pools.

---

#### POLMaxPoolMovement: 0
Caps how much liquidity the protocol can move in or out of a single pool at once. With a `0` value, the protocol doesn’t actively “rebalance” or shift large amounts of liquidity. This parameter can help avoid sudden pool swings that might destabilize prices.

---

#### POLSynthUtilization: 0
A threshold controlling how much synthetic usage the protocol’s owned liquidity might allow. If set above `0`, the protocol could generate or hold synths for specific strategies. `0` means no protocol-driven synth activities.

---

#### PauseBond: 0
Indicates if bonding new nodes is paused (`1`) or not (`0`). If set to `1`, no new validators can join, which might happen during emergencies or code upgrades to prevent partial or malicious entries.

---

#### PauseOnSlashThreshold: 1000000000000
If total slash points across the network exceed this massive threshold (e.g., due to widespread misbehavior or an attack), the chain automatically pauses. This “circuit breaker” mechanism protects users and funds while node operators investigate or patch issues.

---

#### PauseUnbond: 0
Indicates if node unbonding is paused (`1`) or allowed (`0`). Halting unbonding can preserve security during critical events, ensuring nodes remain locked in until the situation stabilizes.

---

#### PayBPNodeRewards: 1
A flag (0 or 1) determining whether bond providers (“BP”) also receive a share of node rewards. If `1`, it means providers of node bond capital (often separate from the node operator) share in block rewards, encouraging capital contributions.

---

#### PendingLiquidityAgeLimit: 100800
The maximum blocks (about 7 days) liquidity can remain in a “pending” or “queued” state before the protocol automatically cancels it. This prevents indefinite half-joined liquidity, which can cause confusion and potential exploit scenarios.

---

#### PermittedSolvencyGap: 100
The tolerated difference (likely in basis points or percentage) between the protocol’s reported solvency and its actual on-chain solvency. If the difference grows beyond this parameter (e.g., more than 1%), the system might flag a solvency issue and trigger protective or investigative actions.

---

#### PoolCycle: 43200
Represents the interval (about 3 days) for pool-related operations—like enabling a newly staged pool or reviewing pool statuses. Often aligns with `ChurnInterval` so major tasks (vault churn and pool updates) happen in sync.

---

#### PoolDepthForYggFundingMin: 5000000000000000
The minimum pool depth (in RUNE units) required before that pool’s assets can be used to fund a Yggdrasil vault. Ensures only sufficiently large, liquid pools are tapped for Yggdrasil, maintaining solvency and reducing partial-funding complexities.

---

#### PreferredAssetOutboundFeeMultiplier: 100
Used to adjust outbound fees for “preferred” assets. `100` basis points typically means a 1× multiplier—no discount or premium. If the protocol wants to incentivize certain chain usage, it might set this lower to reduce fees (e.g., 50 basis points for half cost).

---

#### RagnarokProcessNumOfLPPerIteration: 200
During a **Ragnarok** event (network-wide shutdown or major vault drain), the protocol processes a batch of 200 liquidity providers each iteration (often each block). This setting prevents processing thousands of LPs at once, which could exceed block gas limits or cause huge volatility in a single block.

---

#### RescheduleCoalesceBlocks: 0
If set to a non-zero value, the network tries to coalesce or combine multiple outbounds or tasks within a certain block window, improving efficiency. With `0`, tasks are scheduled individually, possibly leading to more frequent but smaller transactions.

---

#### SaversStreamingSwapsInterval: 0
If non-zero, the protocol would automatically trigger “streaming swaps” for savers at defined intervals (in blocks). A `0` means no forced streaming swaps, so savers’ swaps only occur when explicitly triggered by a user or another protocol action.

---

#### SigningTransactionPeriod: 300
Nodes must sign outbound transactions within 300 blocks (about 30 minutes) of a keysign request. If they fail, the network can slash them for non-participation. This ensures outbound transactions are executed promptly, preventing indefinite delays.

---

#### SlashPenalty: 15000
A broad “penalty factor” (in basis points) used when slash points are converted into actual bond slashing. `15000` means 150% of some slash formula might be applied, so repeated or severe misbehavior can quickly cause a node to lose a large chunk of its bond.

---

#### SlipFeeAddedBasisPoints: 0
An additional slip-based fee to layer on top of the normal slip fee. If `0`, the protocol doesn’t impose extra slip fees. Some networks might add a small fee to particularly volatile or high-priority swaps as a revenue or anti-spam measure.

---

#### StagedPoolCost: 100000000000
The cost (in RUNE units) to create a new “Staged” pool. This deposit is typically non-trivial to discourage spamming pools with low liquidity. Once a pool meets further criteria, it can progress from “Staged” to “Enabled.”

---

#### StreamingSwapMaxLength: 14400
The maximum number of blocks (about 1 day) over which a streaming swap can be spread. Streaming swaps are split into multiple smaller swaps, minimizing slippage and slip fees. This parameter prevents a swap from dragging on too long.

---

#### StreamingSwapMaxLengthNative: 5256000
An extended maximum length (about 1 year) for streaming swaps that involve **native RUNE/Cacao**. The protocol may allow a much longer timeframe here, enabling large or strategic swaps to happen extremely gradually, further reducing slip fees.

---

#### StreamingSwapMinBPFee: 0
A minimum basis point fee (e.g., 1 = 0.01%) for streaming swaps. If `0`, the protocol imposes no extra fee beyond the normal swap fees. A non-zero minimum could ensure the network collects some revenue from these lengthy operations.

---

#### StreamingSwapPause: 0
Whether streaming swaps are globally paused (`1`) or active (`0`). If paused, users cannot start new streaming swaps. This can be useful if a vulnerability or exploit is discovered in that mechanism.

---

#### SubsidizeReserveMultiplier: 100
A multiplier controlling how much the protocol’s reserve subsidizes certain actions (like liquidity or node bonding). `100` basis points = 1×, meaning no added subsidy. Setting this higher (e.g., 200) would double the normal reserve contributions, incentivizing more liquidity or bond.

---

#### SynthYieldBasisPoints: 6000
The yield rate (in basis points) for synthetic asset holders. `6000` = 60% annualized. The protocol calculates synth yield based on pool performance, overall liquidity, and other factors. This parameter caps or sets a baseline for how much synth holders can earn.

---

#### SynthYieldCycle: 0
Indicates the interval (in blocks) at which the protocol pays out or recalculates synth yield. A value of `0` might mean continuous or event-driven distribution rather than strict block scheduling.

---

#### TNSFeeOnSale: 1000
A fee (in basis points) charged whenever a **Maya Name Service (TNS)** domain/name is sold or transferred to a new owner. `1000` = 10%. This revenue can fund TNS development or go to the protocol treasury.

---

#### TNSFeePerBlock: 2000
An ongoing TNS fee or “rental” cost that accrues each block. Could be 2000 “pennies” of RUNE per block or 2000 basis points in some internal formula. It encourages domain owners to keep renewing or risk losing their name if they can’t cover accrued fees.

---

#### TNSRegisterFee: 100000000000
The registration cost (in RUNE units) to claim a new TNS name. This helps prevent squatters from claiming too many domains. Only those who value a name enough to pay the fee typically register it.

---

#### TargetOutboundFeeSurplusRune: 10000000000000
A buffer of RUNE the protocol aims to keep on hand to cover outbound fees, especially if external chain gas fees spike. Having this surplus ensures user withdrawals and cross-chain transactions proceed even in turbulent market conditions.

---

#### TxOutDelayMax: 17280
The maximum delay (in blocks) the protocol allows for scheduling outbounds. If the network is busy, outbounds might be deferred slightly to spread out usage. `17280` blocks is about 1.2 days at 6 seconds per block.

---

#### TxOutDelayRate: 250000000000
A rate factor used in the formula that calculates how quickly the protocol schedules or delays outbounds relative to pool depths and ongoing transactions. Larger values can lead to more delay under heavy load, preventing immediate draining.

---

#### ValidatorMaxRewardRatio: 1
Caps how much of the total block rewards can go to validators (versus liquidity providers). A value of `1` often means 100% if needed, but in practice, the protocol typically splits rewards between node operators, liquidity providers, and other categories. This sets the upper bound on node distribution.

---

#### VirtualMultSynths: 2
A coefficient that *artificially inflates* synthetic depth in swap or yield calculations. If `2`, the protocol treats the synth portion as double its real size for slip fees or certain formulas. This can reduce slip fees on synth creation/redemption, making synth usage more attractive.

---

#### VirtualMultSynthsBasisPoints: 10000
The basis points equivalent of `VirtualMultSynths`. `10000` basis points = 100% = 1× multiplier. However, if combined with the above parameter or changed from the default, it can amplify (or reduce) the perceived synth depth in the pools.

---

#### WithdrawDaysTier1: 200
The approximate number of days (200) for Tier 1 withdrawals—used in protocols that implement tiered withdrawal schedules. A higher day count can encourage longer-term liquidity. Tier 1 might have certain benefits (like lower exit fees) in exchange for a longer locked period.

---

#### WithdrawDaysTier2: 90
Similar concept as Tier 1 but with a shorter lock time (3 months). Potentially, Tier 2 withdrawal might have different fees, slip protections, or yield calculations.

---

#### WithdrawDaysTier3: 30
The shortest of the listed withdrawal tiers (1 month). Typically, Tier 3 participants can exit faster but might receive lower protection or pay higher fees. Each tier is about balancing flexibility against protocol stability.

---

#### WithdrawLimitTier1: 50
Possibly the maximum percentage that can be withdrawn at once (or over a certain period) for Tier 1 participants. This ensures large liquidity providers don’t remove their entire stake suddenly, stabilizing pools and prices.

---

#### WithdrawLimitTier2: 150
A larger limit for Tier 2, potentially meaning participants can withdraw up to 150% of some baseline measure—depending on how the protocol calculates cumulative, rolling, or partial withdrawals.

---

#### WithdrawLimitTier3: 450
An even higher limit for Tier 3. Tiers can be cumulative or progressive. The precise mechanics depend on the network’s design for scheduling withdrawals and capping large outflows.

---

#### WithdrawTier1: 1  
#### WithdrawTier2: 2  
#### WithdrawTier3: 3
Numeric identifiers for the three tiers, used in internal code to apply the correct rules, durations, and limits for each withdrawal category.

---

#### YggFundLimit: 50
A percentage limit on how much of a pool (or total bond) can be allocated to Yggdrasil vaults. By capping Yggdrasil funding at 50%, the protocol ensures not all assets are placed in smaller, node-specific vaults, preserving a healthy balance in Asgard vaults.

---

#### YggFundRetry: 1000
Number of blocks after which the network retries funding Yggdrasil vaults if it failed initially (e.g., due to a node being offline or not signing). This gives time to resolve issues before attempting another fund transaction.

---

#### ZeroImpLossProtectionBlocks: 720000
The number of blocks (about 50 days) after which an LP is fully covered by the network’s **impermanent loss protection**. Before that, coverage might be partial or pro-rated. This encourages medium- to long-term liquidity provision rather than quick exits.

---

## bool_values

#### StrictBondLiquidityRatio: false
If set to `true`, the protocol enforces a strict ratio between the total **bonded** RUNE (node bonds) and the total **pooled** RUNE (liquidity). A strict ratio ensures node security keeps pace with liquidity, but can also limit growth if liquidity floods in. With `false`, the protocol allows looser coupling, giving the network more flexibility at the risk of lower synergy between bond security and pool depth.

---

## string_values

#### DefaultPoolStatus: Staged
The initial status assigned to newly created pools. **“Staged”** means the pool is recognized but not yet actively traded or yielding. The pool remains staged until it meets minimum depth or other criteria, at which point it can be moved to **“Enabled”** status for live swaps.
