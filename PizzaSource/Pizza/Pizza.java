package Pizza;
import java.util.*;
import Pizza.*;

/**
 * Pizza is a system for finding the best N-topping pizza for a group of
 * people.
 *
 * Written by Matthew Sachs, 2006-03-08, for a lecture on unit testing
 * in Brandeis University's COSI 22a.  Source and lecture notes are released
 * into the public domain.
 *
 * @author Matthew Sachs
 * @version 1.0
 * @see <a href="http://www.zevils.com/writings/unit-testing/">http://www.zevils.com/writings/unit-testing/</a>
 */

public class Pizza {
	private HashSet constraints;
	private static HashMap ToppingsMap; //name -> topping
	private static Topping[] AllToppings;

	public static Topping[] AllToppings() { return AllToppings; }

	/**
	 * Set the list of possible toppings.  This must be called before
	 * constructing a Pizza.
	 */
	public static void setAllToppings(Topping[] ts) {
		AllToppings = new Topping[ts.length];
		System.arraycopy(ts, 0, AllToppings, 0, ts.length);
		computeToppingsMap();
	}
	private static void computeToppingsMap() {
		ToppingsMap = new HashMap();
		for(int i = 0; i < AllToppings.length; i++) {
			ToppingsMap.put(AllToppings[i].name(), AllToppings[i]);
		}
	}
	public static Topping getTopping(String name) throws MustSetToppingsException {
		return (Topping)ToppingsMap.get(name);
	}

	public Pizza() throws MustSetToppingsException {
		if(AllToppings == null) throw new MustSetToppingsException();
		constraints = new HashSet();
	}
	public Set constraints() { return constraints; }
	public void addConstraint(ToppingConstraint c) { constraints.add(c); }

	/**
	 * Minimal set of toppings which satisfy the constraints.
	 */
	public Set toppingsMinimal() throws ImpossiblePizzaException {
		return toppings(0);
	}

	/**
	 * Largest set of toppings which satisfy the constraints.
	 */
	public Set toppingsMaximal() throws ImpossiblePizzaException {
		return toppings(AllToppings.length);
	}

	/**
	 * Aim for an n-topping pizza, might get more or less.
	 */
	public Set toppings(int targetToppingCount) throws ImpossiblePizzaException {
		HashSet unsatisfiedMandatory = new HashSet();
		HashSet toppings = new HashSet();
		HashSet possibleToppings = new HashSet(AllToppings.length);
		HashMap toppingConstraintSatMap = new HashMap();

		for(int i = 0; i < AllToppings.length; i++) {
			possibleToppings.add(AllToppings[i]);
		}


		//First we worry about mandatory constraints.

		Iterator i = constraints.iterator();
		while(i.hasNext()) {
			ToppingConstraint c = (ToppingConstraint)i.next();
			if(c.isMandatory()) {
				if(c.isNegative()) {
					Iterator j = possibleToppings.iterator();
					while(j.hasNext()) {
						Topping t = (Topping)j.next();
						if(c.matches(t))
							j.remove();
					}
				} else {
					unsatisfiedMandatory.add(c);
				}
			}
		}

		//Build up a map from Topping t -> Constraints satisfied by t
		i = possibleToppings.iterator();
		while(i.hasNext()) {
			Topping t = (Topping)i.next();
			HashSet h = new HashSet();

			Iterator j = constraints.iterator();
			while(j.hasNext()) {
				ToppingConstraint c = (ToppingConstraint)j.next();
				if(c.isMandatory() && c.isNegative()) continue;
				if(c.matches(t)) h.add(c);
			}

			toppingConstraintSatMap.put(t, h);
		}

		//Okay, at this point we've removed the toppings that
		//someone refuses to have on their pizza.  Now add the
		//toppings that someone *insists* on having.  When we have
		//a choice of toppings which satisfy one of these constraints,
		//pick that one that satisfies the most *mandatory*
		//constraints.

		while(unsatisfiedMandatory.size() > 0) {
			Topping bestTopping = null;
			int bestToppingScore = 0;

			i = possibleToppings.iterator();
			while(i.hasNext()) {
				Topping t = (Topping)i.next();
				HashSet satisfies = (HashSet)toppingConstraintSatMap.get(t);

				int toppingScore = 0;
				Iterator j = satisfies.iterator();
				while(j.hasNext()) {
					ToppingConstraint c = (ToppingConstraint)j.next();
					if(!unsatisfiedMandatory.contains(c)) continue;
					toppingScore++;
				}
				if(toppingScore > bestToppingScore) {
					bestToppingScore = toppingScore;
					bestTopping = t;
				}
			}

			if(bestTopping == null) throw new ImpossiblePizzaException();
			toppings.add(bestTopping);
			HashSet satisfies = (HashSet)toppingConstraintSatMap.get(bestTopping);
			i = satisfies.iterator();
			while(i.hasNext()) {
				unsatisfiedMandatory.remove(i.next());
			}
		}


		//Alright, mandatory constraints satisfied.
		//If the pizza isn't big enough yet, add some more toppings.
		//Add them in order of how happy they make people according
		//to the optional constraints.

		Topping remainingToppings[] = (Topping[])possibleToppings.toArray(new Topping[0]);
		final HashMap toppingScores = new HashMap(remainingToppings.length);
		for(int j = 0; j < remainingToppings.length; j++) {
			HashSet satisfies = (HashSet)toppingConstraintSatMap.get(remainingToppings[j]);

			int toppingScore = 0;
			Iterator k = satisfies.iterator();
			while(k.hasNext()) {
				ToppingConstraint c = (ToppingConstraint)k.next();
				if(c.isMandatory()) 
					continue;
				else if(c.isNegative())
					toppingScore--;
				else
					toppingScore++;
			}

			toppingScores.put(remainingToppings[j], new Integer(toppingScore));
		}

		class ToppingScoreComparator implements Comparator {
			ToppingScoreComparator() {}
			public int compare(Object o1, Object o2) {
				return ((Integer)toppingScores.get(o2)).compareTo(
					toppingScores.get(o1));
			}
		}
		Arrays.sort(remainingToppings, new ToppingScoreComparator());

		for(int j = 0;
		   (j < remainingToppings.length) && 
		   (toppings.size() < targetToppingCount); j++) {
			toppings.add(remainingToppings[j]);
			possibleToppings.remove(remainingToppings[j]);
		}

		return toppings;
	}
}
